

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
import 'package:uuid/uuid.dart';


class ResultsScreen extends StatefulWidget {
  final AppData appData;
  const ResultsScreen({super.key,  required this.appData});

  @override
  State<ResultsScreen> createState()=> _ResultsScreenState();

}


class _ResultsScreenState extends State<ResultsScreen>{
  final factory = tercen.ServiceFactory();
  RightScreenLayout layout = RightScreenLayout();
  

  Future<void> _downloadReport() async {
    
  }

  Future<bool> _readWorkflow() async{
    for( sci.Step stp in widget.appData.workflow.steps){
      if(stp.name == "Export Report"){
        sci.DataStep expStp = stp as sci.DataStep;
        sci.CompositeRelation cr = expStp.computedRelation as sci.CompositeRelation;
        sci.Schema reportSchema =  await factory.tableSchemaService.get( cr.joinOperators[0].rightRelation.id );
        print(reportSchema.toJson());
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    
    layout.addWidget(
      paddingAbove: RightScreenLayout.paddingLarge,
      addTextWithIcon(Icons.download, "Download Report", Styles.text, (){

      })
    );
    layout.addWidget(
      paddingAbove: RightScreenLayout.paddingMedium,
      addTextWithIcon(Icons.link_rounded, "Go to Project", Styles.text, (){
        //TODO
      })
    );

    // return layout.buildScreenWidget();
    return FutureBuilder(
      future: _readWorkflow(), 
      builder: (context, snapshot ){
        if( snapshot.hasData ){
          return Text("WIP");
        }else{
          return const Center(
                    child: CircularProgressIndicator(),
                  );
        }
        
      }
    );

  }
}