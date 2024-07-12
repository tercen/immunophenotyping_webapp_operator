

import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:list_picker/list_picker.dart';
import 'package:web/web.dart' as web;

class AnnotationScreen extends StatefulWidget {
  final Map<String, Object> dh;
  const AnnotationScreen({super.key,  required this.dh});

  @override
  State<AnnotationScreen> createState()=> _AnnotationScreenState();

}


class _AnnotationScreenState extends State<AnnotationScreen>{
  // late Map<String, Object> dataHandler;


  // _AnnotationScreenState( ){
  //   dataHandler = widget.dh;
  // }
  @override
  Widget build(BuildContext context) {
    if( widget.dh.isEmpty ){
      return const Material(
        child: Text("Not yet implemented"),
      );
    }else{
      List<String> chs = widget.dh["channel_annotations"] as List<String>;
      return Material(
        child: Text(chs[0]),
      );
    }
    
  }
}