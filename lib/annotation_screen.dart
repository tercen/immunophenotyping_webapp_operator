

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:immunophenotyping_template_assistant/ui_utils.dart';
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
  AnnotationDataSource(this.tbl );

  @override
  DataRow? getRow(int index) {
    var ctrl = TextEditingController(text: tbl.columns[1].values[index]);
    return DataRow(
          cells: <DataCell>[
            DataCell(Text(tbl.columns[0].values[index])),
            DataCell(
              TextField(
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
  late sci.Table channelAnnotationTbl;

  // @override
  // Future<void> initState() async {
  //   super.initState();

    
  //   // widget.appData.channelAnnotationTbl = res;
  // }

  // _AnnotationScreenState( ){
  //   dataHandler = widget.dh;
  // }

  Future<sci.Table> _readTable() async {
    print("Reading table");
    sci.Schema sch = await factory.tableSchemaService.get(widget.appData.channelAnnotationDoc.id);
    print("Read schema");
    var _channelAnnotationTbl = await factory.tableSchemaService.select(sch.id, ["channel_name", "channel_description"], 0, sch.nRows);
    print("Read table");

    return _channelAnnotationTbl;
  }
  @override
  Widget build(BuildContext context) {
    
    
    DataTableSource dataSource = AnnotationDataSource(channelAnnotationTbl);
    
    return FutureBuilder(
      future: _readTable(), 
      builder: (context, snapshot ){
        if( snapshot.hasData ){
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
                          onPressed: null, 
                          child: Text("Update Description")
                        )
                      )
                      
                    ],
                  );
              
        }else{
          return Center(
                    child: CircularProgressIndicator(),
                  );
        }
      }
    );

    
  
    
  }
}