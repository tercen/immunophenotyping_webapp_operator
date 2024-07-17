import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:immunophenotyping_template_assistant/annotation_screen.dart';
import 'package:immunophenotyping_template_assistant/data.dart';
import 'package:immunophenotyping_template_assistant/fcs_load_screen.dart';
import 'package:immunophenotyping_template_assistant/settings_screen.dart';
import 'package:immunophenotyping_template_assistant/util.dart';


//TODO list
// 1: Use InkWell on left panel to navigate screens on the right
// *: Use MediaQuery to scale text across the application

void main() => runApp(const ImmunophenotypingApp());

class ImmunophenotypingApp extends StatelessWidget {
  const ImmunophenotypingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
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


class _TwoColumnHomeState extends State<TwoColumnHome>{
  static const String FCS_LOAD_SCREEN = "FcsLoadScreen";
  static const String ANNOTATION_SCREEN = "AnnotationScreen";
  static const String SETTINGS_SCREEN = "SettingsScreen";

  List<LeftMenuItem> leftMenuList = [];

  // final Widget _verticalDivider = Expanded(child: Container(constraints: const BoxConstraints(maxHeight: 1000, maxWidth: 5, minHeight: 50), color: Colors.black,) );

  final Map<String, Object> crossScreenData = {};
  final AppData appData = AppData();
  String selectedScreen = _TwoColumnHomeState.FCS_LOAD_SCREEN;

  
  @override
  initState() {
    super.initState();
    leftMenuList.add( LeftMenuItem(Icons.home_rounded, "FCS Files", _TwoColumnHomeState.FCS_LOAD_SCREEN, true));
    leftMenuList.add( LeftMenuItem(Icons.search_rounded, "Annotations", _TwoColumnHomeState.ANNOTATION_SCREEN, false));
    leftMenuList.add( LeftMenuItem(Icons.settings, "Settings", _TwoColumnHomeState.SETTINGS_SCREEN, false));

    Timer.periodic(const Duration(milliseconds: 500), (tmr){
      if(appData.channelAnnotationDoc.id != "" && leftMenuList[1].enabled == false){
        setState(() {
          leftMenuList[1].enabled = true;  
          leftMenuList[2].enabled = true;  
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
      child:ListView(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      children: leftItems,
    ));
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
                      setState(() {
                        selectedScreen = screenTo;
                      });
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
      default:
        return FcsLoadScreen( appData: appData  );
    }
  
    
  }


  @override
  Widget build(BuildContext context) {
    var wdg = Align(
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
    );


    return FutureBuilder(
      future: initFactory(),
      builder: (context, data) {
          if (data.hasData) {
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