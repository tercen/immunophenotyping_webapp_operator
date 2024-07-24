

import 'dart:async';
import 'dart:io';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:immunophenotyping_template_assistant/data.dart';
import 'package:immunophenotyping_template_assistant/ui_utils.dart';
import 'package:immunophenotyping_template_assistant/util.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:list_picker/list_picker.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:web/web.dart' as web;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tson/tson.dart' as tson;
import 'package:uuid/uuid.dart';

class FcsLoadScreen extends StatefulWidget {
  final AppData appData;

  const FcsLoadScreen({super.key,  required this.appData});

  @override
  State<FcsLoadScreen> createState()=> _FcsLoadScreenState();

}

//FIXME Differential analysis has a filter called first channel which uses annot.channel_id. This, however, is unavailable as a factor. 
// Nonetheless, this works with the default data. Check this with Faris on Monday

//TODO Improve general screen layout
//TODO Fix progress message
//TODO Check existing progress name
//TODO Check file types for drop
//TODO better upload/finished feedback
//TODO add filename as a second table in the CSVTask
class UploadFile {
  String filename;
  bool uploaded;

  UploadFile(this.filename, this.uploaded);
}


class _FcsLoadScreenState extends State<FcsLoadScreen>{
  //State vars
  bool finishedUploading = false;
  bool enableUpload = false;

  late ProgressDialog progressDialog = ProgressDialog(context: context);
  
  int total = -1;
  int processed = -1;
  late StreamSubscription<sci.TaskEvent> sub;

  String progress = "";
  final factory = tercen.ServiceFactory();
  late DropzoneViewController dvController;
  late FilePickerResult result;
  String selectedTeam = "Please select a team";

  Color dvBackground = Colors.white;
  List<UploadFile> filesToUpload = [UploadFile("Drag Files Here", false)];
  List<web.File> htmlFileList = [];
  var workflowTfController = TextEditingController(text: "Immunophenotyping Workflow");
  var patController = TextEditingController(text: "");

  final List<String> teamNameList = [];
  sci.Project project = sci.Project();
  late Map<String, Object> dataHandler;


  List<sci.Project> projectList = [];


  @override
  void initState () {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _loadTeams();
      
    });

   
  }

  Future<void> _loadTeams() async {
    var token = Uri.base.queryParameters["token"] ?? '';
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

    List<sci.Team> teamList = await factory.teamService.findTeamByOwner(keys: [decodedToken["data"]["u"]]);

      for( var team in teamList){
      teamNameList.add(team.name);
    }

  }


  List<Widget> _buildFileList(){
    List<Widget> wdgList = [];
    for(int i = 0; i < filesToUpload.length; i++){
      if( filesToUpload[i].filename != "Drag Files Here"){
        Row entry = Row(
          children: [
            filesToUpload[i].uploaded 
                  ? const Icon(Icons.check) 
                  : InkWell(
                        child: const Icon(Icons.delete),
                        onTap: () {
                          setState(() {
                            filesToUpload.removeAt(i);  
                          });
                          
                        },
                    ), 
            Text(filesToUpload[i].filename, style: const TextStyle(fontSize: 14, color: Colors.black45))
          ],
        );           
        wdgList.add(entry);
      }else{
        wdgList.add(Text(filesToUpload[i].filename, style: const TextStyle(fontSize: 14, color: Colors.black45)));
      }
    }

    return wdgList;
  }

  void _updateFilesToUpload(web.File wf){
    if( filesToUpload[0].filename == "Drag Files Here"){
      filesToUpload.removeAt(0);
    }
    filesToUpload.add(UploadFile(wf.name, false));

    htmlFileList.add(wf);
  }


  void _uploadFiles() async {
    var uuid = const Uuid();


    // Create a project to store the workflow
    if( project.id == "" ){
      var projectList = await factory.projectService.findByTeamAndIsPublicAndLastModifiedDate(startKey: selectedTeam, endKey: selectedTeam);
      bool createProject = true;
      for( var proj in projectList){
        if(proj.name == workflowTfController.text){
          project = proj;
          createProject = false;
        }
      }

      if( createProject == true ){
        project.name = workflowTfController.text;
        project.acl.owner = selectedTeam;
        project = await factory.projectService.create(project);
      }

      // Import the immunophenotyping workflow
      progressDialog.update(msg: "Importing workflow");
      sci.GitProjectTask projectTask = sci.GitProjectTask()
          ..state = sci.InitState()
          ..owner = selectedTeam;

      projectTask.meta.add(sci.Pair.from("PROJECT_ID", project.id));
      projectTask.meta.add(sci.Pair.from("PROJECT_REV", project.rev));
      projectTask.meta.add(sci.Pair.from("GIT_ACTION", "reset/pull"));
      projectTask.meta.add(sci.Pair.from("GIT_PAT", patController.text));
      projectTask.meta.add(sci.Pair.from("GIT_URL", "https://github.com/tercen/flow_core_immunophenotyping_template_demo"));
      projectTask.meta.add(sci.Pair.from("GIT_TAG", "0.1.0"));
      projectTask.meta.add(sci.Pair.from("GIT_BRANCH", "main"));
      projectTask.meta.add(sci.Pair.from("GIT_MESSAGE", ""));
        // ..meta = projectMeta;

      

      projectTask = await factory.taskService.create(projectTask) as sci.GitProjectTask;
      await factory.taskService.runTask(projectTask.id);
      await factory.taskService.waitDone(projectTask.id);
      
    }

    List<sci.FileDocument> uploadedDocs = [];
    List<String> docIds = [];
    List<String> dotDocIds = [];
    
    for( int i = 0; i < htmlFileList.length; i++ ){
      web.File file = htmlFileList[i];
      var bytes = await dvController.getFileData(file);
      sci.FileDocument docToUpload = sci.FileDocument()
              ..name = file.name
              ..projectId = project.id
              ..acl.owner = selectedTeam;

      progressDialog.update(msg: "Uploading ${file.name}");
      uploadedDocs.add( await factory.fileService.upload(docToUpload, Stream.fromIterable([bytes]) ) );

      setState(() {
        filesToUpload[i].uploaded = true;
      });

      docIds.add(uploadedDocs[i].id);
      dotDocIds.add(uuid.v4());
    }

    // Reading FCS
    progressDialog.update(msg: "Checking ReadFCS Operator");
    // 1. Get operator
    var installedOperators = await factory.documentService.findOperatorByOwnerLastModifiedDate(startKey: selectedTeam, endKey: '');
    sci.Document op = sci.Document();
    for( var o in installedOperators ){
      if( o.name == "FCS"){
        print("Found FCS operator installed (version ${op.version})");
        op = o;
      }
    }


    // 2. Prepare the computation task
    sci.CubeQuery query = sci.CubeQuery();
    query.operatorSettings.operatorRef.operatorId = op.id;
    query.operatorSettings.operatorRef.operatorKind = op.kind;
    query.operatorSettings.operatorRef.name = op.name;
    query.operatorSettings.operatorRef.version = op.version;

    // Query Projection
    sci.Factor docFactor = sci.Factor()
            ..name = "documentId"
            ..type = "string";

    query.colColumns.add(docFactor);


    // Data to feed projection
    sci.Table tbl = sci.Table();

    sci.Column col = sci.Column()
          ..name = "documentId"
          ..type = "string"
          ..id = "documentId"
          ..nRows = 1
          ..size = -1
          ..values = tson.CStringList.fromList(dotDocIds);
    
    tbl.columns.add(col);

    col = sci.Column()
          ..name = ".documentId"
          ..type = "string"
          ..id = ".documentId"
          ..nRows = 1
          ..size = -1
          ..values = tson.CStringList.fromList(docIds);
    
    tbl.columns.add(col);

    var id = uuid.v4();
    sci.InMemoryRelation rel = sci.InMemoryRelation()
            ..id = id
            ..inMemoryTable = tbl;

    query.relation = rel;
    query.axisQueries.add(sci.CubeAxisQuery());
    

    sci.RunComputationTask compTask = sci.RunComputationTask()
          ..state = sci.InitState()
          ..owner = selectedTeam
          ..query = query
          ..projectId = project.id;
    
    
    progressDialog.update(msg: "Reading FCS files");
    compTask = await factory.taskService.create(compTask) as sci.RunComputationTask;


    
    var taskStream = factory.eventService.listenTaskChannel(compTask.id, true).asBroadcastStream();
    

    sub = taskStream.listen((evt){
      var evtMap = evt.toJson();

      // print(evtMap);
      if(evtMap["kind"] == "TaskStateEvent"){
        if( evtMap["state"]["kind"] == "DoneState" ){
        }
        //Process event log
        
      }
    });


    sub.onDone((){
      _getComputedRelation(compTask.id);
      
      finishedUploading = true;
      widget.appData.uploadRun = true;
    });

  }

  List<sci.SimpleRelation> _getSimpleRelations(sci.Relation relation){
    List<sci.SimpleRelation> l = [];

    switch (relation.kind) {
      case "SimpleRelation":
        l.add(relation as sci.SimpleRelation);
        break;
      case "CompositeRelation":
        sci.CompositeRelation cr = relation as sci.CompositeRelation;
        List<sci.JoinOperator> joList = cr.joinOperators;
        l.addAll(_getSimpleRelations(cr.mainRelation));
        for(var jo in joList){
          l.addAll(_getSimpleRelations(jo.rightRelation));
        }
      case "RenameRelation":
        sci.RenameRelation rr = relation as sci.RenameRelation;
        l.addAll(_getSimpleRelations(rr.relation));

        // 
      default:
    }

    return l;
  }


  void _getComputedRelation(String taskId) async{
    // Works for zip file...

    var compTask = await factory.taskService.get(taskId) as sci.RunComputationTask;

    print(compTask.computedRelation.toJson());
    // sci.CompositeRelation rel = compTask.computedRelation as sci.CompositeRelation;
    // sci.CompositeRelation cr = rel.joinOperators[0].rightRelation as sci.CompositeRelation;
    

    List<sci.SimpleRelation> relations = _getSimpleRelations(compTask.computedRelation);
    // relations[0]; //MEasurements
    // relations[1]; //Observations == check by name
    sci.Schema measurementSch = sci.Schema();
    // sci.Schema observationsSch = sci.Schema();
    for(var r in relations ){
      sci.Schema sch = await factory.tableSchemaService.get(r.id);
      if( sch.name == "Measurements"){
        measurementSch = sch;
      }
      // if( sch.name == "Observations"){
        // observationsSch = sch;
      // }
    }

    List<String> colNames = [];
    for( var col in measurementSch.columns ){
      colNames.add(col.name);
    }

    sci.Table measurementTbl = await factory.tableSchemaService.select(measurementSch.id, colNames, 0, measurementSch.nRows);
    // sci.Table observationTbl = await factory.tableSchemaService.select(observationsSch.id, ["eventId", "filename"], 0, observationsSch.nRows);

    List<String> filenames = [];
    int fileColIdx = 0;
    for( var i = 0; i < measurementTbl.columns.length; i++){
      if(measurementTbl.columns[i].name == "fileId"){
        fileColIdx = i;
      }
    }
    for( var i = 0; i < measurementTbl.nRows; i++){
      filenames.add(filesToUpload[measurementTbl.columns[fileColIdx].values[i]-1].filename); // Starts at 1
    }

    print("Creating column");
    sci.Column fileCol = sci.Column()
          ..type = "string"
          ..name = "filename"
          ..id = "filename"
          ..nRows = filenames.length
          ..size = -1
          ..values = tson.CStringList.fromList(filenames);
    measurementTbl.columns.add(fileCol);
    measurementTbl.properties.name = "Measurements";
    
    widget.appData.measurementsTbl = measurementTbl;

    print("Uploading table");
    uploadTable(measurementTbl, "FCS_Measurements",
                 compTask.projectId, 
                 compTask.owner,
                 "");

    List<sci.ProjectDocument> projObjs = await factory.projectDocumentService.findProjectObjectsByFolderAndName(startKey: [project.id, "ufff0", "ufff0"], endKey: [project.id, "", ""]);

    for( var po in projObjs ){
      //TODO Need to check for && po.name.contains(uploadedFiledoc name ...)
      if(po.name.contains( "Channel-Descriptions" )  ){
        sci.Schema sch = await factory.tableSchemaService.get(po.id);
        sci.Table res = await factory.tableSchemaService.select(sch.id, ["channel_name", "channel_description", "channel_id"], 0, sch.nRows);
        // res.columns[2].type = "string";
        widget.appData.channelAnnotationTbl = res;
        widget.appData.channelAnnotationDoc = po;
      }
    }

  }

  
  void  _processSingleFileDrop(ev){
    if (ev is web.File) {
      setState(() {
        _updateFilesToUpload(ev);
      });
    } 
  }

  void _doUpload(){
    finishedUploading = false;


    progressDialog.show(
                msg: "Starting upload, please wait", 
                progressBgColor: Colors.white,
                progressValueColor: const Color.fromARGB(255, 76, 18, 211),
                barrierColor: const Color.fromARGB(125, 0, 0, 0),
    );
    
    _uploadFiles();

    Timer.periodic(const Duration(milliseconds: 250), (tmr){
      if( finishedUploading == true){
        tmr.cancel();
        sub.cancel();

        if( progressDialog.isOpen()){
          progressDialog.close();
          setState(() {
            enableUpload = false;
          });
        }
        
      }
    });

  }

  @override
  Widget build(BuildContext context) {
    RightScreenLayout layout = RightScreenLayout()
    ..addWidget(
          TextField(
              controller: workflowTfController,
              style: Styles.textH1,
              onTapOutside: null, // Should check availability
              decoration: 
                const InputDecoration(
                  border: UnderlineInputBorder(),

                ),
            )
          )
    ..addWidget(
          paddingAbove: RightScreenLayout.paddingLarge,
          ElevatedButton(
              style: Styles.buttonEnabled,
              child: const Text("Select Team", style: Styles.textButton,),
              onPressed: ()  async {
                String team = ( await showPickerDialog(
                  context: context,
                  label: "",
                  items: teamNameList,
                ))!;

                setState(() {
                  selectedTeam = team;
                  enableUpload = true;
                  widget.appData.selectedTeam = selectedTeam;
                });
                // teamTfController.text = selectedTeam;
              }
            ),
            
          )
    ..addWidget(
      paddingAbove: RightScreenLayout.paddingSmall,
      Text( 
        selectedTeam, 
        style: Styles.text
      )
    )
    ..addWidget(
      paddingAbove: RightScreenLayout.paddingLarge,
      const Text("Upload FCS Files.", style: Styles.textH2)
    )
    ..addWidget(
      paddingAbove: RightScreenLayout.paddingMedium,
      Table(
        columnWidths: const {
          0: FixedColumnWidth(30),
          1: IntrinsicColumnWidth()
        },
        children: [
          TableRow(
            children: [
              Material( 
                child: InkWell(
                  onTap: () async {
                    result = (await FilePicker.platform.pickFiles())!;
                  },
                  child: const Icon(Icons.add_circle_outline_rounded),
                )
              ),
              const TableCell(child: Align(
                alignment: Alignment.center,
                child: Text("Choose Files", style: Styles.text),
              )
              )
              
              
            ]
          )
        ],
      )
    )
    ..addWidget(
      paddingAbove: RightScreenLayout.paddingSmall,
      Stack(
        children: [
          SizedBox(
            height: 200,
            width: 400,

            child: Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.blueGrey), borderRadius: BorderRadius.circular(2.0),color: dvBackground,),
              child: ListView(
                scrollDirection: Axis.vertical,
                children: _buildFileList(),
              ),
            )
          ),

          SizedBox(
            height: 200,
            width: 400,
            child: 
              DropzoneView(
                
                operation: DragOperation.copy,
                onCreated: (ctrl) => dvController = ctrl,
                onLeave: () {
                  setState(() {
                    dvBackground = Colors.white;
                  });
                },
                onHover: () {
                  setState(() {
                    dvBackground = Colors.cyan.shade50;
                  });
                },
                onDrop:  (ev) async => _processSingleFileDrop(ev),
                onDropMultiple: (dynamic ev) => (List<dynamic> ev) => print('Drop multiple: $ev'),
              ),
          )
        ],
      )
    )
    // ..addWidget(
    //   paddingAbove: RightScreenLayout.paddingLarge,
    //   const Text("Github Token", style: Styles.textH2)
    // )
    // ..addWidget(
    //     paddingAbove: RightScreenLayout.paddingSmall,
    //     SizedBox(
    //       width: Styles.tfWidthLarge,
    //       child: 
    //         TextField(
    //           controller: patController,
    //           style: Styles.text,
    //           decoration: 
    //             InputDecoration(
    //               border: OutlineInputBorder(borderRadius: Styles.borderRounding ),

    //           )
    //         ),
    //     )   
    //   )
    ..addWidget(
      paddingAbove: RightScreenLayout.paddingLarge,
      ElevatedButton(
          style: enableUpload 
            ? Styles.buttonEnabled
            : Styles.buttonDisabled,
          onPressed: () {
            enableUpload 
            ? _doUpload()
            : null;
          },

          child: const Text("Upload", style: Styles.textButton,)
      )
    );

    return layout.buildScreenWidget();
 
  }

}