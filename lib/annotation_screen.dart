

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
    return DataRow(
          cells: <DataCell>[
            DataCell(Text(tbl.columns[0].values[index])),
            DataCell(Text(tbl.columns[1].values[index])),
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
          PaginatedDataTable(
            columns: const <DataColumn>[
              DataColumn(
                label: Text('Name'),
              ),
              DataColumn(
                label: Text('Age'),
              ),
              
            ],
        source: dataSource,
      
        )
      );
    }
    
  }
}