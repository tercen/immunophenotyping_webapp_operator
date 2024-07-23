

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
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

class ResultsScreen extends StatefulWidget {
  final AppData appData;
  const ResultsScreen({super.key,  required this.appData});

  @override
  State<ResultsScreen> createState()=> _ResultsScreenState();

}


class ResultSchemaInfo {
  String filenameCol = "";
  String mimetypeCol = "";
  String contentCol = "";
  String schemaId;
  int nRows;

  ResultSchemaInfo(this.schemaId, this.nRows);
}

class _ResultsScreenState extends State<ResultsScreen>{
  final factory = tercen.ServiceFactory();
  RightScreenLayout layout = RightScreenLayout();
  

  Future<void> _downloadReport() async {
    
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


  Future<ResultSchemaInfo> _readWorkflowResultInfo() async{
    
    for( sci.Step stp in widget.appData.workflow.steps){
      if(stp.name == "Export Report"){
        sci.DataStep expStp = stp as sci.DataStep;
        List<sci.SimpleRelation> simpleRels = _getSimpleRelations(expStp.computedRelation);
        
        print("Found ${simpleRels.length} relations");
        sci.Schema reportSchema =  await factory.tableSchemaService.get( simpleRels[0].id );

        ResultSchemaInfo resultInfo = ResultSchemaInfo( simpleRels[0].id, reportSchema.nRows );
        for( sci.ColumnSchema col in reportSchema.columns){
          
          if( col.name.contains("filename")){
            resultInfo.filenameCol = col.name;
          }

          if( col.name.contains("mimetype")){
            resultInfo.filenameCol = col.name;
          }

          if( col.name.contains("content")){
            resultInfo.filenameCol = col.name;
          }
          
        }
        print("Read result info");
        return resultInfo;
      }
    }
    return ResultSchemaInfo("", 0) ;
  }

  void _doDownload(ResultSchemaInfo info) async {
    sci.Table contentTable = await factory.tableSchemaService.select(info.schemaId, [info.filenameCol, info.mimetypeCol, info.contentCol], 0, info.nRows);
          
    final _mimetype = contentTable.columns[1].values[0];
    final _filename = contentTable.columns[2].values[0];
    print("Will download $_filename");
    // final _base64 = base64Encode(contentTable.columns[2].values[0]);
    final _base64 = contentTable.columns[2].values[0];
    print("Will download $_base64");

    //   // Create the link with the file
    // final anchor =
    AnchorElement(href: 'data:$_mimetype;base64,$_base64')
      ..target = 'blank'
      ..download = _filename
      ..click();
    // trigger download
    // document.body.append(anchor);
    // anchor.click();
    // anchor.remove();

  }

  @override
  Widget build(BuildContext context) {
    


    // return layout.buildScreenWidget();
    return FutureBuilder(
      future: _readWorkflowResultInfo(), 
      builder: (BuildContext context, AsyncSnapshot snapshot ){
        if( snapshot.connectionState == ConnectionState.done && snapshot.hasData && widget.appData.workflowRun == true){
          print("Adding widget (snapshot data is ${snapshot.data})");
          layout.addWidget(
          paddingAbove: RightScreenLayout.paddingSmall,
          addTextWithIcon(Icons.download, "Download Report", Styles.text, (){
              print("Trying to download (snapshot data is ${snapshot.data})");

            // try {
              // ResultSchemaInfo info = snapshot.data;
              // print("Will do download for ${info.filenameCol}");
              // if( info.nRows > 0 ){
                // print("Trying to download");
                // _doDownload(info);
              // }else{
                // print("No rows");
              // }
            // } catch (e) {
              // print("Waiting...");
            // }
            
            
          })
        );
        // layout.addWidget(
        //   paddingAbove: RightScreenLayout.paddingMedium,
        //   addTextWithIcon(Icons.link_rounded, "Go to Project", Styles.text, (){
            
        //     //TODO
        //       //              html.AnchorElement anchorElement =  new html.AnchorElement(href: url);
        //       //  anchorElement.download = url;
        //       //  anchorElement.click();
        //   })
        // );

          return layout.buildScreenWidget();
        }else{
          return const Center(
                    child: CircularProgressIndicator(),
                  );
        }
        
      }
    );

  }
}