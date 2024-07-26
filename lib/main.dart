import 'dart:async';
import 'dart:html';

import 'package:flutter/material.dart';
import 'package:immunophenotyping_template_assistant/annotation_screen.dart';
import 'package:immunophenotyping_template_assistant/data.dart';
import 'package:immunophenotyping_template_assistant/fcs_load_screen.dart';
import 'package:immunophenotyping_template_assistant/results_screen.dart';
import 'package:immunophenotyping_template_assistant/settings_screen.dart';
import 'package:immunophenotyping_template_assistant/util.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;


//TODO list
// 1: Use InkWell on left panel to navigate screens on the right
// *: Use MediaQuery to scale text across the application

void main() => runApp(const ImmunophenotypingApp());

class ImmunophenotypingApp extends StatelessWidget {
  const ImmunophenotypingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      color: Colors.white,
      home: TwoColumnHome(),
    );
  }
}


class TwoColumnHome extends StatefulWidget {
  const TwoColumnHome({super.key});

  @override
  State<TwoColumnHome> createState()=> _TwoColumnHomeState();

}


class LeftMenuItem {
  IconData icon;
  String label;
  String screenLink;
  bool enabled;

  LeftMenuItem(this.icon, this.label, this.screenLink, this.enabled);

}

class ResultSchemaInfo {
  String filenameCol = "";
  String mimetypeCol = "";
  String contentCol = "";
  String schemaId;
  int nRows;

  ResultSchemaInfo(this.schemaId, this.nRows);
}

class _TwoColumnHomeState extends State<TwoColumnHome>{
  static const String FCS_LOAD_SCREEN = "FcsLoadScreen";
  static const String ANNOTATION_SCREEN = "AnnotationScreen";
  static const String SETTINGS_SCREEN = "SettingsScreen";
  static const String RESULTS_SCREEN = "ResultsScreen";
  static const String PROJECT_LINK = "projectLink";
  static const String REPORT_LINK = "reportLink";
  
  late var factory;
  List<LeftMenuItem> leftMenuList = [];

  // final Widget _verticalDivider = Expanded(child: Container(constraints: const BoxConstraints(maxHeight: 1000, maxWidth: 5, minHeight: 50), color: Colors.black,) );

  final Map<String, Object> crossScreenData = {};
  final AppData appData = AppData();
  String selectedScreen = _TwoColumnHomeState.FCS_LOAD_SCREEN;
  ResultSchemaInfo resultInfo = ResultSchemaInfo( "", 0 );



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
    print("Reading workflow results: ${appData.workflow}");
    for( sci.Step stp in appData.workflow.steps){
      if(stp.name == "Export Report"){
        print("Found export");
        sci.DataStep expStp = stp as sci.DataStep;
        List<sci.SimpleRelation> simpleRels = _getSimpleRelations(expStp.computedRelation);
        print("Num simple rels ${simpleRels.length}");
        for(var sr in simpleRels){
          print(sr.toJson());
        }
        sci.Schema reportSchema =  await factory.tableSchemaService.get( simpleRels[0].id );

        ResultSchemaInfo resultInfo = ResultSchemaInfo( simpleRels[0].id, reportSchema.nRows );
        for( sci.ColumnSchema col in reportSchema.columns){
          print("Column ${col.name}");
          if( col.name.contains("filename")){
            resultInfo.filenameCol = col.name;
          }

          if( col.name.contains("mimetype")){
            resultInfo.mimetypeCol = col.name;
          }

          if( col.name.contains("content")){
            resultInfo.contentCol = col.name;
          }

          print("Info ${resultInfo.nRows}, ${resultInfo.filenameCol}, ${resultInfo.mimetypeCol}, ${resultInfo.contentCol}");

          return resultInfo;
        }
      }
    }

    return ResultSchemaInfo("NONE", 0);
  }


  @override
  initState() {
    super.initState();
    leftMenuList.add( LeftMenuItem(Icons.home_rounded, "FCS Files", _TwoColumnHomeState.FCS_LOAD_SCREEN, true));
    leftMenuList.add( LeftMenuItem(Icons.search_rounded, "Annotations", _TwoColumnHomeState.ANNOTATION_SCREEN, false));
    leftMenuList.add( LeftMenuItem(Icons.settings, "Settings", _TwoColumnHomeState.SETTINGS_SCREEN, false));
    leftMenuList.add( LeftMenuItem(Icons.file_present_rounded, "Results", _TwoColumnHomeState.RESULTS_SCREEN, false));
    leftMenuList.add( LeftMenuItem(Icons.download, "Download Report", _TwoColumnHomeState.REPORT_LINK, false));
    leftMenuList.add( LeftMenuItem(Icons.apps_outlined, "Open Project", _TwoColumnHomeState.PROJECT_LINK, false));
    

    Timer.periodic(const Duration(milliseconds: 100), (tmr){
      if(appData.uploadRun == true && leftMenuList[1].enabled == false){
        setState(() {
          leftMenuList[1].enabled = true;  
          leftMenuList[2].enabled = true;  
          leftMenuList[5].enabled = true;  
          
        });
        tmr.cancel();  
      }
    });

    Timer.periodic(const Duration(milliseconds: 100), (tmr){
      if(appData.workflowRun == true && leftMenuList[3].enabled == false){
        setState(() async {
          leftMenuList[3].enabled = true;  
          leftMenuList[4].enabled = true;  

          // resultInfo = await _readWorkflowResultInfo();
        });
        tmr.cancel();  
      }
    });
  }

  Widget _buildLeftTab(){
    List<Widget> leftItems = [];

    for( var item in leftMenuList){
      leftItems.add(  
        _addItem(item.icon, item.label, item.screenLink, item.enabled)
      );
    }
    return Material( 
      
      child:
        Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: 
          ListView(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            children: leftItems,
          ),
      )
        );
  }

  void _doRedirect(String destination) async {
    final Uri url = Uri.parse(destination);
    await launchUrl(url, webOnlyWindowName: '_blank');
  }


  void _doDownload() async {
    ResultSchemaInfo info = await _readWorkflowResultInfo();
    print("Trying to download ${info.filenameCol}");
    print("Trying to download ${info.nRows}");

    if( info.nRows == 0){
      return;
    }
    sci.Table contentTable = await factory.tableSchemaService.select(info.schemaId, [info.filenameCol, info.mimetypeCol, info.contentCol], 0, info.nRows);
          
    final _mimetype = contentTable.columns[1].values[0];
    final _filename = contentTable.columns[0].values[0];
    final _base64 = contentTable.columns[2].values[0];


    //   // Create the link with the file
    // final anchor =
    AnchorElement(href: 'data:$_mimetype;base64,$_base64')
      ..target = 'blank'
      ..download = _filename
      ..click();
  }


  Widget _addItem( IconData icon, String label, String screenTo, bool enabled){
    var inset = const EdgeInsets.symmetric(vertical: 5, horizontal: 5);

    
    var tbl = Align(
      alignment: Alignment.centerLeft,
      child: Table(
      columnWidths: const {
        0: FixedColumnWidth(32),
        1: IntrinsicColumnWidth()
      },


      children: [
        TableRow(
          children: [
            Padding(padding: inset, child:Icon(icon)),
            Padding(padding: inset, child:
                InkWell(
                  child: enabled 
                      ? Text(label, style: const TextStyle(color: Colors.black, fontSize: 18),)
                      : Text(label, style: const TextStyle(color: Colors.grey, fontSize: 18),),
                  onTap: () {
                    if( enabled ){
                      if( screenTo == _TwoColumnHomeState.PROJECT_LINK){
                        String host = "";
                        if( Uri.base.port != 80 ){
                          host = "${Uri.base.host}:${Uri.base.port}";
                        }else{
                          host = Uri.base.host;
                        }
                        _doRedirect("${Uri.base.scheme}://$host/${appData.selectedTeam}/p/${appData.workflow.projectId}");
                      } else if( screenTo == _TwoColumnHomeState.REPORT_LINK){
                        // resultInfo = _readWorkflowResultInfo();
                        _doDownload();
                      }else{
                        setState(() {
                          
                          selectedScreen = screenTo;
                        });
                      }
                      
                    }
                    
                  },
                )
                
            ),
          ]

        )
        
      ],
    ),
    );
    return tbl;
  }



  Widget _buildRightScreen(){

    switch( selectedScreen){
      case _TwoColumnHomeState.FCS_LOAD_SCREEN:
        return FcsLoadScreen( appData: appData,);
      case _TwoColumnHomeState.ANNOTATION_SCREEN:
        return AnnotationScreen(appData: appData,);
      case _TwoColumnHomeState.SETTINGS_SCREEN:
        return SettingsScreen(appData: appData,);
      case _TwoColumnHomeState.RESULTS_SCREEN:
        return ResultsScreen(appData: appData,);
      default:
        return FcsLoadScreen( appData: appData  );
    }
  
    
  }


  @override
  Widget build(BuildContext context) {
    var wdg = 
    Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: 
        Align(
          alignment: Alignment.topLeft,
          child: 
          //#TODO Might need to switch to row....
          Table(

            columnWidths: 
              const {
                0: FixedColumnWidth(250.0),
                // 1: FixedColumnWidth(5.0),
                2: IntrinsicColumnWidth(),
              },
            children: [
              TableRow(
                children: [
                  _buildLeftTab(),
                  // _verticalDivider,
                  _buildRightScreen(),
                ]
              )
            ],
          ),
        ),
    );


    return FutureBuilder(
      future: initFactory(),
      builder: (context, data) {
          if (data.hasData) {
            factory = tercen.ServiceFactory();
            return wdg;
          } else if (data.hasError) {
            return Text(data.error!.toString());
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        }
     );
  }


}