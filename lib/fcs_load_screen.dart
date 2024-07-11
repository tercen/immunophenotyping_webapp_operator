

import 'dart:async';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:list_picker/list_picker.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:web/web.dart' as web;
import 'package:flutter_modal_dialog/flutter_modal_dialog.dart';
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tson/tson.dart' as tson;
import 'package:uuid/uuid.dart';

class FcsLoadScreen extends StatefulWidget {
  const FcsLoadScreen({super.key});

  @override
  State<FcsLoadScreen> createState()=> _FcsLoadScreenState();

}


class _FcsLoadScreenState extends State<FcsLoadScreen>{
  late ProgressDialog progressDialog = ProgressDialog(context: context);
  bool finishedUploading = false;
  int total = -1;
  int processed = -1;

  String progress = "";
  final factory = tercen.ServiceFactory();
  late DropzoneViewController dvController;
  late FilePickerResult result;
  String selectedTeam = "Please select a team";
  Color dvBackground = Colors.white;
  List<String> filesToUpload = ["Drag Files Here"];
  List<web.File> htmlFileList = [];
  var workflowTfController = TextEditingController(text: "Immunophenotyping Workflow");

  final List<String> teamNameList = [];
  sci.Project project = sci.Project();

  @override
  void initState () {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _loadTeams();
      // _debugInfo();
      
    });

    // http://127.0.0.1:5400/lib/w/5e8e784622396f3064cd7cd90e7376e7/ds/b3718281-eb72-47a1-b962-003c49b9e539
    
  }

  Future<void> _debugInfo() async {
    sci.Workflow wkf = await factory.workflowService.get("5e8e784622396f3064cd7cd90e7376e7");
    for( var stp in wkf.steps){
      print(stp.toJson());
    }
  }
  Future<void> _loadTeams() async {
    var token = Uri.base.queryParameters["token"] ?? '';
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

    // List<String> teamNameList = [];

    List<sci.Team> teamList = await factory.teamService.findTeamByOwner(keys: [decodedToken["data"]["u"]]);

      for( var team in teamList){
      teamNameList.add(team.name);
    }

    // setState(() {
      
    // });
    // return teamNameList;
  }


  List<Widget> _buildFileList(){
    // if( filesToUpload.isEmpty){
    //   filesToUpload.add("No Files Selected");
    // }else{
    List<Widget> wdgList = [];
    for(int i = 0; i < filesToUpload.length; i++){
      if( filesToUpload[i] != "Drag Files Here"){
        Row entry = Row(
          children: [
            const Icon(Icons.delete_rounded),
            Text(filesToUpload[i], style: const TextStyle(fontSize: 14, color: Colors.black45))
          ],
        );           
        wdgList.add(entry);
      }else{
        wdgList.add(Text(filesToUpload[i], style: const TextStyle(fontSize: 14, color: Colors.black45)));
      }
    }
    // }
    return wdgList;
  }

  void _updateFilesToUpload(web.File wf){
    if( filesToUpload[0] == "Drag Files Here"){
      filesToUpload.removeAt(0);
    }
    filesToUpload.add(wf.name);

    htmlFileList.add(wf);
  }


  void _uploadFiles() async {
    var uuid = const Uuid();


    // Create a project to store the workflow
    if( project.id == "" ){
      project.name = workflowTfController.text;
      project.acl.owner = selectedTeam;
      project = await factory.projectService.create(project);
    }

    List<sci.FileDocument> uploadedDocs = [];

    for( web.File file in htmlFileList ){
      print("Uploading ${file.name}");
      var bytes = await dvController.getFileData(file);
      sci.FileDocument docToUpload = sci.FileDocument()
              ..name = file.name
              ..projectId = project.id
              ..acl.owner = selectedTeam;
      
      
      uploadedDocs.add( await factory.fileService.upload(docToUpload, Stream.fromIterable([bytes]) ) );
      print("Done with ${file.name}");
    }
    
    // Reading FCS
    // 1. Get operator
    print("Getting operator");
    var installedOperators = await factory.documentService.findOperatorByOwnerLastModifiedDate(startKey: selectedTeam, endKey: '');
    sci.Document op = sci.Document();
    for( var o in installedOperators ){
      if( o.name == "FCS"){
        print("Found ReadFCS operator installed");
        op = o;
      }
    }


    // 2. Prepare the computation task
    sci.CubeQuery query = sci.CubeQuery();
    query.operatorSettings.operatorRef.operatorId = op.id;
    query.operatorSettings.operatorRef.operatorKind = op.kind;
    query.operatorSettings.operatorRef.name = op.name;

    // Query Projection
    sci.Factor docFactor = sci.Factor()
            ..name = "documentId"
            ..type = "string";

    query.colColumns.add(docFactor);


    // Data to feed projection
    sci.Table tbl = sci.Table();
        // ..projectId = project.id
        // ..name = "fcs_data"
        // ..nRows = 1
        // ..isDeleted = false
        // ..acl.owner = selectedTeam;

    sci.Column col = sci.Column()
          ..name = "documentId"
          ..type = "string"
          ..id = "documentId"
          ..nRows = 1
          ..size = -1
          ..values = tson.CStringList.fromList([uuid.v4()]);
    
    tbl.columns.add(col);

    col = sci.Column()
          ..name = ".documentId"
          ..type = "string"
          ..id = ".documentId"
          ..nRows = 1
          ..size = -1
          ..values = tson.CStringList.fromList([uploadedDocs[0].id]);
    
    tbl.columns.add(col);

    // sch = await factory.tableSchemaService.create(sch);
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
    
    

    compTask = await factory.taskService.create(compTask) as sci.RunComputationTask;


    var taskStream = factory.eventService.listenTaskChannel(compTask.id, true).asBroadcastStream();
    
    //{kind: TaskProgressEvent, id: , isDeleted: false, rev: ,
    // date: {kind: Date, value: 2024-07-11T16:29:54.226033Z}, taskId: 3adc6ed4b2e0e95f81fa2488033fb5f9, message: measurement, total: 8, actual: 2}
    var currentFile = "";
    var sub = taskStream.listen((evt){
      print("sub");
    });

    sub.onDone((){
      print("Done");
      finishedUploading = true;
    });

    await for (var evt in taskStream) {
      var evtMap = evt.toJson();
      print("for");
      // if(evtMap["kind"] == "TaskProgressEvent"){
      //     setState(() {
      //       if( currentFile != uploadedDocs[0].name){
      //         currentFile = uploadedDocs[0].name;
      //         progressDialog.close();
      //         progressDialog.show(
      //               msg: "Processing file ${uploadedDocs[0].name}", 
      //               max: evt.toJson()["total"],
      //               barrierColor: const Color.fromARGB(125, 0, 0, 0));
      //       }
      //       progressDialog.update(value: evt.toJson()["actual"]);
      //     });
      //   // }
      // }
    }

    sub.cancel();
    finishedUploading = true;
    // Navigator.pop(context);
    print("done");
    
    
  }

  
  void  _processSingleFileDrop(ev){
    if (ev is web.File) {
      setState(() {
        _updateFilesToUpload(ev);
      });
      // final bytes = await controller1.getFileData(ev);
      // print(bytes.sublist(0, min(bytes.length, 20)));
    } 
  }

  Widget _addAlignedWidget(Widget wdg){
    return Align(
      alignment: Alignment.centerLeft,
      child: 
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: wdg,
        ),
    );
  }

  Widget _addSeparator( {String spacing = "intermediate"} ){
    double height;
    switch(spacing){
      case "intermediate":
        height = 22.0;
      case "small":
        height = 8.0;
      case "large":
        height = 30.0;
      default:
        height = 25.0;
    }

    return SizedBox(height: height,);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        children: [
          _addAlignedWidget(
            // const Text("Immunophenotyping Workflow", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),)
            TextField(
              controller: workflowTfController,
              decoration: 
                const InputDecoration(
                  border: UnderlineInputBorder()
                ),
            )
          ),

          _addSeparator(),

          _addAlignedWidget(ElevatedButton(
              child: const Text("Select Team"),
              onPressed: ()  async {
                String team = ( await showPickerDialog(
                  context: context,
                  label: "",
                  items: teamNameList,
                ))!;

                setState(() {
                  selectedTeam = team;
                });
                // teamTfController.text = selectedTeam;
              }
            ),
          ),


          _addSeparator(spacing: "small"),
          

          _addAlignedWidget(Material( 
              child: 
              Text(
                selectedTeam, 
                style: 
                  const TextStyle(fontSize: 16, color: Colors.black)
              ),
            ) 
          ),
         

          _addSeparator(spacing: "intermediate"),

          _addAlignedWidget(const Text("Upload FCS Files.", style: TextStyle(fontSize: 16, color: Colors.black),)),

          _addSeparator(spacing: "small"),

          _addAlignedWidget(
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
                    const Text("Choose Files", style: TextStyle(fontSize: 16, color: Colors.black),)
                  ]
                )
              ],
            )
          ),


          _addSeparator(spacing: "small"),


          _addAlignedWidget(
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
          ),

          _addSeparator(spacing: "small"),

          _addAlignedWidget(
            ElevatedButton(

                onPressed: () {
                  finishedUploading = false;
                  // ModalDialog.waiting(
                  //     context: context,

                  //     title: ModalTitle(text: progress),
                  // );

                  progressDialog.show(msg: "Starting upload");
                  

                  _uploadFiles();

                  Timer.periodic(const Duration(milliseconds: 250), (tmr){
                    if( finishedUploading == true){
                      tmr.cancel();
                      progressDialog.close();
                    }
                  });

                }, 
                child: const Text("Upload")
            )
          ),

        ],
      ),
    );
 
  }

}