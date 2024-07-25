

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

class AnnotationScreen extends StatefulWidget {
  final AppData appData;
  const AnnotationScreen({super.key,  required this.appData});

  @override
  State<AnnotationScreen> createState()=> _AnnotationScreenState();

}


class AnnotationDataSource extends DataTableSource{
  sci.Table tbl;
  List<TextEditingController> controllerList = [];
  List<int> changedRows = [];
  AnnotationDataSource(this.tbl );

  @override
  DataRow? getRow(int index) {
    var ctrl = TextEditingController(text: tbl.columns[1].values[index]);
    

    if( controllerList.length <= index ){
      controllerList.add(ctrl);
    }

    return DataRow(
          cells: <DataCell>[
            
            DataCell(

              SizedBox.expand(
                child: Container(
                  color: index % 2 == 0 ? Colors.white : const Color.fromARGB(50, 210, 220, 255),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(tbl.columns[0].values[index], style: Styles.text,),
                  )
                  
                ),
              )
              
            ),
            DataCell(
               SizedBox.expand(
                child: Container(
                  color: index % 2 == 0 ? Colors.white : const Color.fromARGB(50, 210, 220, 255),
                  child: TextField(
                    onChanged: (txt) {
                      if( !changedRows.contains(index) ){
                        changedRows.add(index);
                      }
                    },
                    controller: ctrl,
                    decoration: 
                      const InputDecoration(
                        border: UnderlineInputBorder()
                      )
                    
                  ),
                ),
              )
              
            ),
          ],
        );
  }
  
  @override
  bool get isRowCountApproximate => false;
  
  @override
  int get rowCount => tbl.nRows;
  
  @override
  int get selectedRowCount => 0;
}

class _AnnotationScreenState extends State<AnnotationScreen>{
  // late Map<String, Object> dataHandler;
  final factory = tercen.ServiceFactory();
  late ProgressDialog progressDialog = ProgressDialog(context: context);
  late sci.Schema annotSch;

  bool finishedUpdate = false;
  
  void _updateAnnotations(sci.Table tbl, List<int> changedRows, List<String> changedText ) async {
    if(changedRows.isNotEmpty){
      List<String> newAnnotations = List.from(tbl.columns[1].values);
      

      for(int i = 0; i < changedRows.length; i++ ){
        newAnnotations[changedRows[i]] = changedText[i];
      }

      var annotationTable = sci.Table()
          ..properties.name = widget.appData.channelAnnotationDoc.name;
                              
      annotationTable.columns
        ..add(sci.Column()
          ..type = 'string'
          ..name = tbl.columns[0].name
          ..values =
              tson.CStringList.fromList(List.from(tbl.columns[0].values)))
        ..add(sci.Column()
          ..type = 'string'
          ..name = tbl.columns[1].name
          ..values = tson.CStringList.fromList(newAnnotations));


      print("Uploading channel annotation to folderId ${widget.appData.channelAnnotationDoc.folderId}");
      await uploadTable(annotationTable, 
                annotationTable.properties.name, 
                widget.appData.channelAnnotationDoc.projectId, 
                widget.appData.channelAnnotationDoc.acl.owner,
                widget.appData.channelAnnotationDoc.folderId
      );

      widget.appData.channelAnnotationTbl = annotationTable;

      
      await factory.projectDocumentService.delete(widget.appData.channelAnnotationDoc.id, widget.appData.channelAnnotationDoc.rev);
      finishedUpdate = true;
    }
  }

  Future<sci.Table> _readTable() async {
    annotSch = await factory.tableSchemaService.get(widget.appData.channelAnnotationDoc.id);
    var channelAnnotationTbl = await factory.tableSchemaService.select(annotSch.id, ["channel_name", "channel_description"], 0, annotSch.nRows);

    return channelAnnotationTbl;
  }
  @override
  Widget build(BuildContext context) {
    

    return FutureBuilder(
      future: _readTable(), 
      builder: (context, snapshot ){
        
        if( snapshot.hasData ){
          AnnotationDataSource dataSource = AnnotationDataSource(snapshot.requireData);
          RightScreenLayout layout = RightScreenLayout()
          ..addWidget(
            SizedBox(
              width: 800,
              child:                 
                Theme(
                    data: ThemeData(
                      dividerTheme: const DividerThemeData(
                        color: Colors.transparent,
                        space: 0,
                        thickness: 0,
                        indent: 0,
                        endIndent: 0,
                      ),
                      cardTheme: const CardTheme(
                        shadowColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        color: Colors.white,
                        elevation: 0,
                        margin: EdgeInsets.all(0)

                      ),
                      ),

                    child: 
                      PaginatedDataTable(
                        columnSpacing: 0,
                        columns: const <DataColumn>[
                          DataColumn(

                            label: Text('Name', style: Styles.textH2,),
                          ),
                          DataColumn(
                            label: Text('Description', style: Styles.textH2),
                          ),
                          
                        ],
                        source: dataSource,

                  ),
                ),
            )

   
          )
          ..addWidget(
            paddingAbove: RightScreenLayout.paddingLarge,
            ElevatedButton(
              style: setButtonStyle("enabled"),
              onPressed: (){
                progressDialog.show(
                    msg: "Updating annotation table, please wait", 
                    progressBgColor: Colors.white,
                    progressValueColor: const Color.fromARGB(255, 76, 18, 211),
                    barrierColor: const Color.fromARGB(125, 0, 0, 0),
                );



                Timer.periodic(const Duration(milliseconds: 250), (tmr){
                if( finishedUpdate == true){
                  tmr.cancel();

                  if( progressDialog.isOpen()){
                    progressDialog.close();
                  }
                  
                }
              });

              sci.Table tbl = snapshot.requireData;
              List<String> changedText = [];
              for( var idx in dataSource.changedRows ){
                changedText.add(dataSource.controllerList[idx].text);
              }
              _updateAnnotations(tbl, dataSource.changedRows, changedText);
                
                
              }, 
              child: const Text("Update Descriptions", style: Styles.textButton)
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