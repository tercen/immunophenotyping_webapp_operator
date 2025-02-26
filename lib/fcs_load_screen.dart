

import 'dart:async';
import 'dart:io';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

//TODO Check file types for drop


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
  List<DropzoneFileInterface> htmlFileList = [];
  List<PlatformFile> platformFileList = [];
  var workflowTfController = TextEditingController(text: "Immunophenotyping Workflow");
  var patController = TextEditingController(text: "");

  final List<String> teamNameList = [];
  sci.Project project = sci.Project();
  late Map<String, Object> dataHandler;
  late List<sci.ProjectDocument> projectObjects;

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

    sci.User user = await factory.userService.get(decodedToken["data"]["u"]);
    // print(user.toJson());
    // List<sci.Team> teamList = await factory.teamService.findTeamByOwner(keys: [decodedToken["data"]["u"]]);
    // List<sci.Team> teamList2 = await factory.teamService.findTeamByOwner(keys: []);
    // print(teamList.length);
    // print(teamList2.length);

      for( var ace in user.teamAcl.aces){
      teamNameList.add(ace.principals[0].principalId);
    }
    teamNameList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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

  void _updateFilesToUpload(DropzoneFileInterface wf){
    if( filesToUpload[0].filename == "Drag Files Here"){
      filesToUpload.removeAt(0);
    }
    filesToUpload.add(UploadFile(wf.name, false));

    htmlFileList.add(wf);
  }

  void _updateFilesToUploadSingle(PlatformFile wf){


    if( filesToUpload[0].filename == "Drag Files Here"){
      filesToUpload.removeAt(0);
    }
    filesToUpload.add(UploadFile(wf.name, false));

    platformFileList.add(wf);
  }


  sci.ProjectDocument _findByName(List<sci.ProjectDocument> poList, String name){

    for( var po in poList ){
      if( po.name == name ){
        return po;
      }
    }

    return sci.ProjectDocument();
  }

  void _uploadFiles() async {
    var uuid = const Uuid();


        //http://127.0.0.1:5400/test-team/w/4636a61f6867796c23693e7d023b632c/ts/6dba340a-af59-42ba-aea5-55fa7f7b2b4b //CORRECT
    // http://127.0.0.1:5400/test-team/w/4636a61f6867796c23693e7d023b632c/ts/8346b5cb-5e4d-41ae-be35-313abe9500d0 //WRONG

    // var wkf = await factory.workflowService.get("4636a61f6867796c23693e7d023b632c");

    // for( var stp in wkf.steps ){
    //   if( stp.id == "6dba340a-af59-42ba-aea5-55fa7f7b2b4b"){
    //     print("CORRECT:");
    //     print(stp.toJson());
    //     print("........................");
    //   }
    //   if( stp.id == "8346b5cb-5e4d-41ae-be35-313abe9500d0"){
    //     print("WRONG:");
    //     print(stp.toJson());
    //     print("........................");
    //   }
    // }

    // return;

    // Create a project to store the workflow
    if( project.id == "" ){
      print("Selected team is $selectedTeam");
      // var perm = await factory.persistentService.findByKind(keys: ["Project"]);

      
      // var projectList = await factory.projectService.list(perm.map((e) => e.id).toList());
      var projectList = await factory.projectService.findByTeamAndIsPublicAndLastModifiedDate(startKey: [selectedTeam, false, "0000"], endKey: [selectedTeam, true, "9999"]);
      
      
      print("Found ${projectList.length} projects");
      // print("Found ${projectList2.length} projects");
      bool createProject = true;
      for( var proj in projectList){
        print("\t${proj.name} ==? ${workflowTfController.text}");
        if(proj.name == workflowTfController.text){
          print("\t\tPROJECT Already exists, using it");
          project = proj;
          createProject = false;
        }
      }

      widget.appData.projectId = project.id;
      projectObjects = await factory.projectDocumentService.findProjectObjectsByFolderAndName(
                            startKey: [project.id,  "ufff0", "ufff0"], 
                            endKey: [project.id,  "", ""]);


      bool hasWorkflow = false;
      for( var po in projectObjects){
        if(po.name == "Flow Immunophenotyping - PhenoGraph"){
          hasWorkflow = true;
          break;
        }
      }


      if( createProject == true || hasWorkflow == false){
        project.name = workflowTfController.text;
        project.acl.owner = selectedTeam;
        project = await factory.projectService.create(project);
        widget.appData.projectId = project.id;
        // Import the immunophenotyping workflow
        progressDialog.update(msg: "Downloading Project Files. Please wait.");
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





      
    }

    List<sci.FileDocument> uploadedDocs = [];
    List<String> docIds = [];
    List<String> dotDocIds = [];
    int fti = 0;
    for( int i = 0; i < htmlFileList.length; i++ ){
      var file = htmlFileList[i];
      var bytes = await dvController.getFileData(file);

      //DELETE file if it exists...
      
      var poFile = _findByName(projectObjects, file.name);
      if( poFile.id != ''){
        await factory.projectDocumentService.delete(poFile.id, poFile.rev);
      }

      sci.FileDocument docToUpload = sci.FileDocument()
              ..name = file.name
              ..projectId = project.id
              ..acl.owner = selectedTeam;

      progressDialog.update(msg: "Uploading ${file.name}");
      uploadedDocs.add( await factory.fileService.upload(docToUpload, Stream.fromIterable([bytes]) ) );

      setState(() {
        filesToUpload[fti].uploaded = true;
        fti += 1;
      });

      docIds.add(uploadedDocs[i].id);
      dotDocIds.add(uuid.v4());
    }

    for( int i = 0; i < platformFileList.length; i++ ){
      PlatformFile file = platformFileList[i];
      var bytes = file.bytes;

      //DELETE file if it exists...
      
      var poFile = _findByName(projectObjects, file.name);
      if( poFile.id != ''){
        await factory.projectDocumentService.delete(poFile.id, poFile.rev);
      }

      sci.FileDocument docToUpload = sci.FileDocument()
              ..name = file.name
              ..projectId = project.id
              ..acl.owner = selectedTeam;

      progressDialog.update(msg: "Uploading ${file.name}");
      uploadedDocs.add( await factory.fileService.upload(docToUpload, Stream.fromIterable([bytes!]) ) );

      setState(() {
        filesToUpload[fti].uploaded = true;
        fti += 1;
      });

      docIds.add(uploadedDocs[i].id);
      dotDocIds.add(uuid.v4());
    }

    // Reading FCS
    progressDialog.update(msg: "Checking ReadFCS Operator");
    // 1. Get operator

    
    
    
    sci.Document op = sci.Document();
    bool opFound = false;

    // var permOp = await factory.persistentService.findByKind(keys: ["Operator"]);

    // var installedOperators = await factory.projectService.list(permOp.map((e) => e.id).toList());
    var installedOperators = await factory.documentService.findOperatorByOwnerLastModifiedDate(startKey: [selectedTeam, "0000"], endKey: [selectedTeam, "9999"], limit: 1000);
    print("Found ${installedOperators.length} operators");
    for( var o in installedOperators ){
      print(o.name);
    }
    for( var o in installedOperators ){
      if( o.name == "FCS" && o.version == "2.3.0"){
        print("Found FCS operator installed (version ${o.version})");
        op = o;
        opFound = true;
        break;
      }

    }

    if(opFound == false){
      progressDialog.update(msg: "Installing ReadFCS Operator. Please wait.");
      sci.CreateGitOperatorTask installTask = sci.CreateGitOperatorTask()
        ..state = sci.InitState()
        ..version = "2.3.0"
        ..testRequired = false
        ..isDeleted = false
        ..owner = selectedTeam;
      installTask.url.uri = "https://github.com/tercen/read_fcs_operator";

      installTask = await factory.taskService.create(installTask) as sci.CreateGitOperatorTask;
      await factory.taskService.runTask(installTask.id);
      await factory.taskService.waitDone(installTask.id);

      op = await factory.operatorService.get(installTask.operatorId);
      
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
          ..nRows = dotDocIds.length
          ..size = -1
          ..values = tson.CStringList.fromList(dotDocIds);
    
    tbl.columns.add(col);

    col = sci.Column()
          ..name = ".documentId"
          ..type = "string"
          ..id = ".documentId"
          ..nRows = docIds.length
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

      
      if(evtMap["kind"] == "TaskProgressEvent"){
        if( evtMap.keys.contains("message") ){
          print(evtMap);
          var msg = evtMap["message"];
          progressDialog.update(msg: "Reading FCS files: $msg");
        }

        
        //Process event log
        
      }
    });


    sub.onDone((){
      if( finishedUploading == false){
        _getComputedRelation(compTask.id);
      
        finishedUploading = true;
        widget.appData.uploadRun = true;
      }
      
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
    print("Getting computed relation for taskId $taskId");
    
    var compTask = await factory.taskService.get(taskId) as sci.RunComputationTask;
    

    List<sci.SimpleRelation> relations = _getSimpleRelations(compTask.computedRelation);
    
    sci.Schema measurementSch = sci.Schema();
    sci.Schema summarySch = sci.Schema();

    for(var r in relations ){
      sci.Schema sch = await factory.tableSchemaService.get(r.id);

      if( sch.name == "Measurements"){
        measurementSch = sch;
      }
      if( sch.name == "Observations"){
        summarySch = sch;
      }
    }

    var filenameTbl = await factory.tableSchemaService.select(summarySch.id, ["filename"], 0, summarySch.nRows); 
    var filenames = filenameTbl.columns[0].values;

    List<String> colNames = [];
    for( var col in measurementSch.columns ){
      colNames.add(col.name);
    }

    
    sci.Table measurementTbl = await factory.tableSchemaService.select(measurementSch.id, colNames, 0, measurementSch.nRows);


    print("Added all file names");

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



    var schId = await uploadTable(measurementTbl, "Measurements",
                 compTask.projectId, 
                 compTask.owner,
                 "");

                 widget.appData.measurementsSch = await factory.tableSchemaService.get(schId);
    



    // var permDocs = await factory.persistentService.findByKind(keys: ["ProjectObject", "File"]);
    var permDocs = await factory.persistentService.getDependentObjects(compTask.projectId);


    var poFile = _findByName(projectObjects,  "Measurements");

    if( poFile.id != ''){
      // await factory.projectDocumentService.delete(poFile.id, poFile.rev);
    }

    var projObjs = await factory.tableSchemaService.list(permDocs.where((e) => e.kind == "TableSchema").map((e) => e.id).toList()); 

    // List<sci.ProjectDocument> projObjs = await factory.projectDocumentService.findProjectObjectsByFolderAndName(startKey: [project.id, "ufff0", "ufff0"], endKey: [project.id, "", ""]);
    // print(projObjs);
    
    List<String> uniqueFilenames = [];
    for( var fu in filesToUpload ){
      uniqueFilenames.add(fu.filename);
    }
     

    for( var po in projObjs ){
      bool anyFilename = false;
      for( var f in uniqueFilenames ){
        if(po.name.contains(f)){
          anyFilename = true;
        }
      }



      if(po.name.contains( "Channel-Descriptions" ) && anyFilename == true  ){
        sci.Schema sch = await factory.tableSchemaService.get(po.id);
        List<String> cols = ["channel_name", "channel_description"];
        for( var col in sch.columns){
          if(col.name == "channel_id"){
            cols = ["channel_name", "channel_description", "channel_id"];
          }
        }
        sci.Table res = await factory.tableSchemaService.select(sch.id, cols, 0, sch.nRows);

        // // res.columns[2].type = "string";
        widget.appData.channelAnnotationSch = sch;
        widget.appData.channelAnnotationTbl = res;
        widget.appData.channelAnnotationDoc = po;
      }
    }

  }

  
  void  _processSingleFileDrop(ev){
    if (ev is DropzoneFileInterface) {
      setState(() {
        _updateFilesToUpload(ev);
      });
    } 

    if( ev is PlatformFile){
        setState(() {
        _updateFilesToUploadSingle(ev);
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
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: 
                  Material(
                    color: Colors.white, 
                    child: InkWell(
                      onTap: () async {
                        result = (await FilePicker.platform.pickFiles(allowMultiple: false))!;
                        for(var f in result.files){
                          _processSingleFileDrop(f);
                        }
                        
                      },
                      child: const Icon(Icons.add_circle_outline_rounded),
                    )
                  )
              )
              ,

              const TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child:  Text("Choose Files", style: Styles.text)
              ),
              
              
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
                onDropFile:  (ev) async => _processSingleFileDrop(ev),
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