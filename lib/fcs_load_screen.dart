

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:list_picker/list_picker.dart';
import 'package:web/web.dart' as web;
import 'package:flutter_modal_dialog/flutter_modal_dialog.dart';
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;

class FcsLoadScreen extends StatefulWidget {
  const FcsLoadScreen({super.key});

  @override
  State<FcsLoadScreen> createState()=> _FcsLoadScreenState();

}


class _FcsLoadScreenState extends State<FcsLoadScreen>{
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
    });


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
    
    // Create a project to store the workflow
    if( project.id == "" ){
      project.name = workflowTfController.text;
      project.acl.owner = selectedTeam;
      project = await factory.projectService.create(project);
    }
    // var workflowId = Uri.base.queryParameters["workflowId"] ?? '';
    // print("workflowId is $workflowId");

    // var workflow = await factory.workflowService.get(workflowId);
    // var project = await factory.projectService.get(workflow.projectId);
    List<sci.FileDocument> uploadedDocs = [];
    for( web.File file in htmlFileList ){
      print("Uploading ${file.name}");
      var bytes = await dvController.getFileData(file);
      sci.FileDocument docToUpload = sci.FileDocument();
      docToUpload.name = file.name;
      docToUpload.projectId = project.id;
      docToUpload.acl.owner = selectedTeam;

      uploadedDocs.add( await factory.fileService.upload(docToUpload, Stream.fromIterable([bytes]) ));
      print("Done with ${file.name}");
    }
    
    // Reading FCS
    sci.CubeQuery query = sci.CubeQuery();
    sci.Factor docFactor = sci.Factor();
    docFactor.type = "string";
    docFactor.name = "documentId";
    
    query.colColumns.add(docFactor);
    sci.SimpleRelation rel = sci.SimpleRelation();
    rel.id = uploadedDocs[0].id;
    query.relation = rel;

    sci.RunComputationTask compTask = sci.RunComputationTask();
    compTask.state = sci.InitState();
    compTask.owner = selectedTeam;
    compTask.query = query;


    var task = await factory.taskService.create(compTask);
    await factory.taskService.runTask(task.id);
    task = await factory.taskService.waitDone(task.id);


    // print("Creating workflow");
    // // https://github.com/tercen/flow_core_immunophenotyping_template
    // // Create workflow for FCS reading
    // sci.GitProjectTask importTask = sci.GitProjectTask();
    // importTask.owner = selectedTeam;
    // importTask.meta.add(sci.Pair.from("PROJECT_ID", project.id));
    // importTask.meta.add(sci.Pair.from("PROJECT_REV", project.rev));
    // importTask.meta.add(sci.Pair.from("GIT_ACTION", "reset/pull"));
    // importTask.meta.add(sci.Pair.from("GIT_PAT", ""));
    // importTask.meta.add(sci.Pair.from("GIT_URL", "https://github.com/tercen/flow_core_immunophenotyping_template"));
    // importTask.meta.add(sci.Pair.from("GIT_BRANCH", "main"));
    // importTask.meta.add(sci.Pair.from("GIT_MESSAGE", ""));
    // importTask.meta.add(sci.Pair.from("GIT_TAG", "0.1.2"));

    // importTask.state = sci.InitState();

    // var task = await factory.taskService.create(importTask);
    // await factory.taskService.runTask(task.id);
    // task = await factory.taskService.waitDone(task.id);
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
                  ModalDialog.waiting(
                      context: context,
                      title: const ModalTitle(text: "Uploading files and creating workflow. Please wait"),
                  );

                  _uploadFiles();

                   Navigator.pop(context);
                }, 
                child: const Text("Upload")
            )
          ),

        ],
      ),
    );
 
  }

}