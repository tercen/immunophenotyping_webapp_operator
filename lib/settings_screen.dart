

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:immunophenotyping_template_assistant/ui_utils.dart';
import 'package:immunophenotyping_template_assistant/util.dart';
import 'package:list_picker/list_picker.dart';
import 'package:web/web.dart' as web;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_model/sci_model_base.dart' as model;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tson/tson.dart' as tson;
import 'package:immunophenotyping_template_assistant/data.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:json_string/json_string.dart';


class SettingsScreen extends StatefulWidget {
  final AppData appData;
  const SettingsScreen({super.key,  required this.appData});

  @override
  State<SettingsScreen> createState()=> _SettingsScreenState();

}



class SettingsEntry{
  final String name;
  final String hint;
  final String type;
  late String value;
  late List<String> options = [];
  late TextEditingController controller;

  SettingsEntry(this.name, this.hint, this.type, this.value) {
    controller = TextEditingController(text: value); 
  }

  void addOptions(List<String> opt){

    for( var o in opt ){
      options.add(o);
    }
    


  }
}

class _SettingsScreenState extends State<SettingsScreen>{
  // late Map<String, Object> dataHandler;
  final factory = tercen.ServiceFactory();
  late ProgressDialog progressDialog = ProgressDialog(context: context);
  // late sci.Schema annotSch;
  late StreamSubscription<sci.TaskEvent> sub;

  bool finishedRunning = false;
  
  Future<List<SettingsEntry>> _readSettings() async {
    List<SettingsEntry> entries = [];    

    String settingsStr = await DefaultAssetBundle.of(context).loadString("assets/cfg/workflow_settings.json");
    try {
      final jsonString = JsonString(settingsStr);
      final settingsMap = jsonString.decodedValueAsMap;

      
      for(int i = 0; i < settingsMap["settings"].length; i++){
        Map<String, dynamic> jsonEntry = settingsMap["settings"][i];  
        SettingsEntry setting = SettingsEntry(
          jsonEntry["name"],
          jsonEntry["hint"],
          jsonEntry["type"], 
          jsonEntry["value"]);

        if( jsonEntry.keys.contains("options") ){
          setting.addOptions(jsonEntry["options"]);
        }

        entries.add(setting);
      }

    } on Exception catch (e) {
        print('Invalid JSON: $e');
    }

    


    return entries;
  }

  //TODO Move this function to ui_utils.dart
  void _addSettings(RightScreenLayout layout, SettingsEntry settings ){
    layout.addWidget(
      paddingAbove: RightScreenLayout.paddingLarge,
      Text(
        settings.name,
        style: Styles.textH2,
      )
    );

    if( settings.type == "ListSingle"){
      layout.addWidget(
        DropdownButton(
          value: settings.value,
          onTap: null,
          icon: const Icon(Icons.arrow_downward),
          style: Styles.text,
          items: settings.options.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(), 
          onChanged: (String? value){
            setState(() {
              settings.value = value!;
            });
          }
        )
      );

    }else{
      layout.addWidget(
        paddingAbove: RightScreenLayout.paddingSmall,
        SizedBox(
          width: Styles.tfWidthMedium,
          child: 
            TextField(
              controller: settings.controller,
              style: Styles.text,
              decoration: 
                InputDecoration(
                  border: OutlineInputBorder(borderRadius: Styles.borderRounding ),

              )
            ),
        )   
      );
    }
  }




  Future<void> _runWorkflow() async {
    
    List<sci.ProjectDocument> projObjs = await factory.projectDocumentService.findProjectObjectsByFolderAndName(startKey: 
                    [widget.appData.channelAnnotationDoc.projectId, "ufff0", "ufff0"], 
                    endKey: [widget.appData.channelAnnotationDoc.projectId, "", ""]
    );
    List<sci.Workflow>? workflows = projObjs.where((po) => po.kind.toLowerCase() == "workflow").toList() as List<sci.Workflow>;

    print("Found ${workflows.length} workflows");

    for(sci.Step stp in workflows[0].steps){
      if(stp.kind == "TableStep"){
        print(stp.toJson());
      }
    }

    //1. Update annotation table step

    //2. Update data table step


    //3. Run Workflow task




    // sci.RunWorkflowTask workflowTask = sci.RunWorkflowTask();
    // var taskStream = factory.eventService.listenTaskChannel(compTask.id, true).asBroadcastStream();
    

    // sub = taskStream.listen((evt){
    //   var evtMap = evt.toJson();
    //   if(evtMap["kind"] == "TaskProgressEvent"){
    //     //Process event log
    //   }
    // });

    // sub.onDone((){
    //   _getComputedRelation(compTask.id);
      
    //   finishedUploading = true;
    // });
  }

  @override
  Widget build(BuildContext context) {
    

    return FutureBuilder(
      future: _readSettings(), 
      builder: (context, snapshot ){

        if( snapshot.hasData ){
          print("Bu8ilding screen");
          RightScreenLayout layout = RightScreenLayout();

          for( SettingsEntry setting in snapshot.data!){
            _addSettings(layout, setting);
          }

          layout.addWidget(
            
            paddingAbove: RightScreenLayout.paddingLarge,
            ElevatedButton(
              style: setButtonStyle("enabled"),
              onPressed: (){
                progressDialog.show(
                    msg: "Running the workflow. Please wait.", 
                    barrierColor: const Color.fromARGB(125, 0, 0, 0),
                );



                Timer.periodic(const Duration(milliseconds: 250), (tmr){
                if( finishedRunning == true){
                  tmr.cancel();

                  if( progressDialog.isOpen()){
                    progressDialog.close();
                  }
                  
                }
              });

              _runWorkflow();

              // factory.workflowService.
              // sci.Table tbl = snapshot.requireData;
              // List<String> changedText = [];
              // for( var idx in dataSource.changedRows ){
              //   changedText.add(dataSource.controllerList[idx].text);
              // }
              // _updateAnnotations(tbl, dataSource.changedRows, changedText);
                
                
              }, 
              child: const Text("Run Analysis", style: Styles.textButton,)
           )
          );

          return layout.buildScreenWidget();
              
        }else{
          // TODO better place the loading icon
          return const Center(
                    child: CircularProgressIndicator(),
                  );
        }
      }
    );

    
  
    
  }
}