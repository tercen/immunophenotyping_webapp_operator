  import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';



Widget addSeparator( {String spacing = "intermediate"} ){
    double height;
    switch(spacing){
      case "intermediate":
        height = 22.0;
      case "small":
        height = 8.0;
      case "large":
        height = 30.0;
      default:
        height = 25.0;
    }

    return SizedBox(height: height,);
  }



Widget addAlignedWidget(Widget wdg){
  return Align(
    alignment: Alignment.centerLeft,
    child: 
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: wdg,
      ),
  );
}

ButtonStyle setButtonStyle(String state){
  
  switch (state) {
    case "disabled":
      return Styles.buttonDisabled;
    case "enabled":
      return Styles.buttonEnabled;
    default:
      return Styles.buttonEnabled;
  }
}



  Widget addTextWithIcon( IconData icon, String label, TextStyle textStyle, Function? onClick){
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
                  onTap: (){
                    onClick;
                  },
                  child: Text(label, style: textStyle,),
                )
                
            ),
          ]

        )
        
      ],
    ),
    );
    return tbl;
  }

class Styles {
  static const black = Color.fromARGB(255, 26, 26, 41);
  static const gray = Color.fromARGB(255, 180, 180, 190);
  static const darkGray = Color.fromARGB(255, 120, 120, 130);
  static const white = Color.fromARGB(255, 240, 240, 230);

  static final BorderRadius borderRounding = BorderRadius.circular(8.0); 

  static const double tfWidthSmall = 80;
  static const double tfWidthMedium = 200;
  static const double tfWidthLarge = 400;
  
  //TODO Read from configuration at some point, perhaps
  static const textH1 = TextStyle(fontSize: 20, color: Styles.black, fontWeight: FontWeight.bold);
  static const textH2 = TextStyle(fontSize: 16, color: Styles.black, fontWeight: FontWeight.w600);
  static const text = TextStyle(fontSize: 14, color: Styles.black, fontWeight: FontWeight.w400);
  static const textButton = TextStyle(fontSize: 14, color: Styles.white, fontWeight: FontWeight.w400);
  static const textBlocked = TextStyle(fontSize: 14, color: Styles.white, fontWeight: FontWeight.w400);

  static ButtonStyle buttonEnabled = ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: Styles.borderRounding,
              ),
              backgroundColor: Styles.black,
              foregroundColor: Styles.white);

  static ButtonStyle buttonDisabled = ElevatedButton.styleFrom(

              shape: RoundedRectangleBorder(
                borderRadius: Styles.borderRounding,
              ),
              backgroundColor: Styles.gray,
              foregroundColor: Styles.darkGray);
  
}


class RightScreenLayout {
  static const double paddingNone = 0;
  static const double paddingSmall = 10;
  static const double paddingMedium = 20;
  static const double paddingLarge = 40;
  List<Widget> children = [];

  void addWidget(Widget wdg, {double paddingAbove = RightScreenLayout.paddingMedium}){
    children.add(SizedBox(height: paddingAbove,));
    children.add(_createAlignedWidget(wdg));
   
  }

  Widget buildScreenWidget(){
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        children: children
      )
    );

  }

  Widget _createAlignedWidget(Widget wdg){
    return Align(
      alignment: Alignment.centerLeft,
      child: 
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: wdg,
        ),
    );
  }

}