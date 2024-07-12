

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:list_picker/list_picker.dart';
import 'package:web/web.dart' as web;
import 'package:sci_tercen_client/sci_client.dart' as sci;
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


  // _AnnotationScreenState( ){
  //   dataHandler = widget.dh;
  // }
  @override
  Widget build(BuildContext context) {
    if( widget.appData.channelAnnotationTbl.columns.isEmpty ){
      return const Material(
        child: Text("Please upload files first."),
      );
    }else{
      // List<String> chs = widget.dh["channel_annotations"] as List<String>;
      DataTableSource dataSource = AnnotationDataSource(widget.appData.channelAnnotationTbl);
      
      return Material(
        child: 
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
      )
          
      );
    }
    
  }
}