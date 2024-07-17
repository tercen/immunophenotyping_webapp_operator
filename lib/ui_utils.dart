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
      return ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 200, 200, 200),
        foregroundColor: const Color.fromARGB(255, 80, 80, 80),
      );


    default:
      return ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: const Color.fromARGB(255, 222, 222, 222),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold
        )
      );
  }
}



class RightScreenLayout {
  static const double spacingSmall = 10;
  static const double spacingMedium = 20;
  static const double spacingLarge = 30;
  List<Widget> children = [];

  void addWidget(Widget wdg, {double paddingAbove = RightScreenLayout.spacingMedium}){
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