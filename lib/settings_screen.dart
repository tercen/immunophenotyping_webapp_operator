

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:immunophenotyping_template_assistant/ui_utils.dart';
import 'package:immunophenotyping_template_assistant/util.dart';
import 'package:intl/intl.dart';
import 'package:list_picker/list_picker.dart';
import 'package:web/web.dart' as web;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_model/sci_model_base.dart' as model;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:tson/tson.dart' as tson;
import 'package:immunophenotyping_template_assistant/data.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';
import 'package:json_string/json_string.dart';
import 'package:uuid/uuid.dart';


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
  final String section;
  final String settingName;
  final String step;
  late String value;
  late List<String> options = [];
  late TextEditingController controller;

  SettingsEntry(this.name, this.section, this.settingName, this.step, this.hint, this.type, this.value) {
    controller = TextEditingController(text: value); 
  }

  void addOptions(List<String> opt){

    for( var o in opt ){
      options.add(o);
    }
  }

  String info(){
    return "Name: $name" + 
          "\nType: $type" +
          "\nValue: $value" +
          "\nSection: $section";
  }
}

class _SettingsScreenState extends State<SettingsScreen>{
  // late Map<String, Object> dataHandler;
  final factory = tercen.ServiceFactory();
  late ProgressDialog progressDialog = ProgressDialog(context: context);
  // late sci.Schema annotSch;
  late StreamSubscription<sci.TaskEvent> sub;
  Map<String, String> dropDownValues = {};
  int finishedSteps = 0;


  bool finishedRunning = false;
  
  Future<List<SettingsEntry>> _readSettings() async {
    List<SettingsEntry> settingsList = [];    

    String settingsStr = await DefaultAssetBundle.of(context).loadString("assets/cfg/workflow_settings.json");
    try {
      final jsonString = JsonString(settingsStr);
      final settingsMap = jsonString.decodedValueAsMap;

      
      for(int i = 0; i < settingsMap["settings"].length; i++){
        Map<String, dynamic> jsonEntry = settingsMap["settings"][i];  
        SettingsEntry setting = SettingsEntry(
          jsonEntry["name"],
          jsonEntry["section"],
          jsonEntry["setting_name"],
          jsonEntry["step"],
          jsonEntry["hint"],
          jsonEntry["type"], 
          jsonEntry["value"]);

        if( jsonEntry.keys.contains("options") ){
          setting.addOptions(jsonEntry["options"]);
        }

        settingsList.add(setting);
      }

    } on Exception catch (e) {
        print('Invalid JSON: $e');
    }

    


    return settingsList;
  }

  RightScreenLayout _createSettingsWidget(RightScreenLayout tile, SettingsEntry setting){
    tile.addWidget(
      paddingAbove: RightScreenLayout.paddingSmall,
      Text(
        setting.name,
        style: Styles.textH2,
      )
    );

    if( setting.type == "ListSingle"){
      
      if(!dropDownValues.containsKey(setting.name)){
        dropDownValues[setting.name] = setting.value;
      }
      
     
      tile.addWidget(
        paddingAbove: RightScreenLayout.paddingSmall,
        
          Material(
            child:         
            Container(
                decoration: const BoxDecoration(color: Colors.white),
                child:  
                  DropdownButton (
                    value: dropDownValues[setting.name],
                    icon: const Icon(Icons.arrow_downward),
                    style: Styles.text,
                    items: setting.options.map<DropdownMenuItem>((String value) {
                          return DropdownMenuItem(
                            value: value,
                            onTap: () {
                              setState(() {
                                dropDownValues[setting.name] = value;
                              });
                            },
                            child: Text(value),
                          );
                        }).toList(), 
                  onChanged: (var value){
                  
                  }
                ),
            )
            ,
          ),

      );

    }else{
      tile.addWidget(
        paddingAbove: RightScreenLayout.paddingSmall,
        SizedBox(
          width: Styles.tfWidthMedium,
          child: 
            TextField(
              controller: setting.controller,
              style: Styles.text,
              decoration: 
                InputDecoration(
                  border: OutlineInputBorder(borderRadius: Styles.borderRounding ),

              )
            ),
        )   
      );
    }

    return tile;
  }

  //TODO Move this function to ui_utils.dart
  void _addSettingsSection(RightScreenLayout layout, List<SettingsEntry> settingsSection ){
    RightScreenLayout tileWidgets = RightScreenLayout();
    for( SettingsEntry setting in settingsSection ){
      tileWidgets = _createSettingsWidget(tileWidgets, setting);
    }
    // print(tileWidgets.children.length);


    layout.addWidget(paddingAbove: RightScreenLayout.paddingMedium,
              Text(settingsSection[0].section, style: Styles.textH1)
    );

    for( Widget wdg in tileWidgets.children ){
      layout.addWidget(paddingAbove: RightScreenLayout.paddingNone , wdg);
    }
    // layout.addWidget(
    //    ExpansionTile(

    //       title: Text(settingsSection[0].section, style: Styles.textH1,),
    //       subtitle: Text(""),
    //       // children:tileWidgets.children,
    //       children: <Widget>[Text("Test")],
    // ));
  }


  bool _updateOperatorSettings(sci.DataStep stp, List<SettingsEntry> settingsList){
    for( var setting in settingsList ){
      if( stp.name == setting.step ){
        for( var i = 0; i < stp.model.operatorSettings.operatorRef.propertyValues.length; i++){
          // print("${stp.model.operatorSettings.operatorRef.propertyValues[i].name} vs ${setting.settingName}");
          if( stp.model.operatorSettings.operatorRef.propertyValues[i].name == setting.settingName ){
            if( setting.type == "ListSingle"){
              stp.model.operatorSettings.operatorRef.propertyValues[i].value = dropDownValues[setting.name]!;
            }else{
              stp.model.operatorSettings.operatorRef.propertyValues[i].value = setting.controller.text;
            }
            
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _runWorkflow(List<SettingsEntry> settingsList) async {
    
    List<sci.ProjectDocument> projObjs = await factory.projectDocumentService.findProjectObjectsByFolderAndName(startKey: 
                    [widget.appData.channelAnnotationDoc.projectId, "ufff0", "ufff0"], 
                    endKey: [widget.appData.channelAnnotationDoc.projectId, "", ""]
    );


    List<sci.ProjectDocument>? workflows = projObjs.where((po) => po.subKind == "Workflow" && po.folderId == "").toList();


    sci.Workflow wkf = await factory.workflowService.get(workflows[0].id);
    
    var uuid = const Uuid();
    for(sci.Step stp in wkf.steps){
      if(stp.kind == "DataStep" ){
        _updateOperatorSettings(stp as sci.DataStep, settingsList);

        
      }
      
      
      if(stp.kind == "TableStep" ){
        if(stp.name == "FCS Data"){
          
          sci.InMemoryRelation rel = sci.InMemoryRelation()
                ..id = uuid.v4()
                ..inMemoryTable = widget.appData.measurementsTbl;
          sci.TableStep tmpStp = stp as sci.TableStep;
          tmpStp.model.relation = rel;
          tmpStp.state.taskState = sci.DoneState();
          stp = tmpStp;

        }

        if(stp.name == "Marker Annotation"){
          sci.InMemoryRelation rel = sci.InMemoryRelation()
                ..id = uuid.v4()
                ..inMemoryTable = widget.appData.channelAnnotationTbl;
          sci.TableStep tmpStp = stp as sci.TableStep;
          tmpStp.model.relation = rel;
          tmpStp.state.taskState = sci.DoneState();
          stp = tmpStp;
        }
      }
    }

    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy_MM_dd_kkmm').format(now);
    // Create a folder for the workflow to run in 
    sci.FolderDocument folder = sci.FolderDocument()
        ..acl.owner = wkf.acl.owner
        ..name = formattedDate
        ..isHidden = false
        ..projectId = wkf.projectId;

    folder = await factory.folderService.create(folder);
    wkf.folderId = folder.id;
    wkf.id = "";
    wkf.rev = "";

        

    wkf = await factory.workflowService.create(wkf);
    
    progressDialog.close(delay: 1);

    progressDialog.show(
        msg: "Running the workflow. Please wait.", 
        max: wkf.steps.length,
        progressType: ProgressType.valuable,
        barrierColor: const Color.fromARGB(125, 0, 0, 0),
    );


    //3. Run Workflow task
    sci.RunWorkflowTask workflowTask = sci.RunWorkflowTask()
          ..state = sci.InitState()
          ..owner = wkf.acl.owner
          ..projectId = wkf.projectId
          ..workflowId = wkf.id
          ..workflowRev = wkf.rev;
    




    workflowTask = await factory.taskService.create(workflowTask) as sci.RunWorkflowTask;
    
    var taskStream = factory.eventService.listenTaskChannel(workflowTask.id, true).asBroadcastStream();
    
    
    sub = taskStream.listen((evt){
      var evtMap = evt.toJson();
      //TODO Handle progress messages better
      print(evtMap);
      if(evtMap["kind"] == "TaskStateEvent"){
        if( evtMap["state"]["kind"] == "DoneState"){
          finishedSteps += 1;
          progressDialog.update(value: finishedSteps);
        }
      }
    });

    sub.onDone(() async {
      finishedRunning = true;
      widget.appData.workflowRun = true;
      widget.appData.workflow = await factory.workflowService.get(wkf.id);
      finishedSteps = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    

    return FutureBuilder(
      future: _readSettings(), 
      builder: (BuildContext context, AsyncSnapshot snapshot ){

        if(  snapshot.connectionState == ConnectionState.done && snapshot.hasData && widget.appData.uploadRun ){
          List<SettingsEntry> settingsList = [];
          if( snapshot.data != null ){
            settingsList = snapshot.data;
          }
          RightScreenLayout layout = RightScreenLayout();

          Map<String, List<SettingsEntry>> sections = {};

          for( SettingsEntry setting in settingsList){
            if(!sections.keys.contains(setting.section)){
              sections[setting.section] = [];
            }
            sections[setting.section]?.add(setting);
          }

          for( MapEntry<String, List<SettingsEntry>> entry in sections.entries){
            // print(entry.key);
            // for( SettingsEntry e in entry.value ){
            //   print(e.info());
            // }
            _addSettingsSection(layout, entry.value);
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

              _runWorkflow(settingsList);
               
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