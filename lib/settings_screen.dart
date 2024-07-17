

import 'dart:async';
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

class SettingsScreen extends StatefulWidget {
  final AppData appData;
  const Settings({super.key,  required this.appData});

  @override
  State<Settings> createState()=> _SettingsScreenState();

}



class SettingsEntry{

}

class _SettingsScreenState extends State<SettingsScreen>{
  // late Map<String, Object> dataHandler;
  final factory = tercen.ServiceFactory();
  late ProgressDialog progressDialog = ProgressDialog(context: context);
  late sci.Schema annotSch;

  bool finishedUpdate = false;
  
  Future<List<SettingsEntry>> _readSettings() async {
    List<SettingsEntry> entries = [];    

    return entries;
  }
  @override
  Widget build(BuildContext context) {
    

    return FutureBuilder(
      future: _readSettings(), 
      builder: (context, snapshot ){
        
        if( snapshot.hasData ){
          return Column(children: [Text("WIP")],);
              
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