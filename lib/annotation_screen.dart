

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:immunophenotyping_template_assistant/ui_utils.dart';
import 'package:immunophenotyping_template_assistant/util.dart';
import 'package:list_picker/list_picker.dart';
import 'package:web/web.dart' as web;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:immunophenotyping_template_assistant/data.dart';

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
    

    if( controllerList.length < index ){
      controllerList.add(ctrl);
    }

    return DataRow(
          cells: <DataCell>[
            DataCell(Text(tbl.columns[0].values[index])),
            DataCell(
              TextField(
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
  late sci.Schema annotSch;
  
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
          return Column(
                    children: [
                      Theme(data: Theme.of(context).copyWith(
                              cardColor: const Color.fromARGB(255, 252, 252, 252),
                              dividerColor: const Color.fromARGB(255, 188, 183, 255),
                            ), 
                            child: 
                                PaginatedDataTable(

                                columns: const <DataColumn>[
                                  DataColumn(
                                    label: Text('Name'),
                                  ),
                                  DataColumn(
                                    label: Text('Description'),
                                  ),
                                  
                                ],
                                source: dataSource,
                      
                        )
                      ),

                      addSeparator(),

                      addAlignedWidget(
                        ElevatedButton(
                          style: setButtonStyle("enabled"),
                          onPressed: (){
                            // sci.ProjectDocument chanAnnotDoc =  widget.appData.channelAnnotationDoc;
                            sci.Table tbl = snapshot.requireData;
                            
                            if(dataSource.changedRows.isNotEmpty){
                              for(int idx in dataSource.changedRows ){
                                tbl.columns[1].values[idx] = dataSource.controllerList[idx].text;
                              }
                              
                              uploadTable(tbl, tbl.properties.name, widget.appData.channelAnnotationDoc.projectId, widget.appData.channelAnnotationDoc.acl.owner);
                              factory.projectDocumentService.delete(widget.appData.channelAnnotationDoc.id, widget.appData.channelAnnotationDoc.rev);
                              
                              // factory.tableSchemaService.update(tbl.)
                              
                            }
                            
                          }, 
                          child: const Text("Update Descriptions")
                        )
                      )
                      
                    ],
                  );
              
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