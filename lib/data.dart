import 'package:sci_tercen_client/sci_client.dart' as sci;


class AppData {
  sci.Table channelAnnotationTbl = sci.Table();  
  sci.Table measurementsTbl = sci.Table();  
  var measurementsSch = sci.Schema();  
  
  sci.Schema channelAnnotationSch = sci.Schema();

  sci.ProjectDocument channelAnnotationDoc = sci.ProjectDocument();
  sci.ProjectDocument measurementsDoc = sci.ProjectDocument();

  String selectedTeam = "";
   
  bool workflowRun = false;
  bool uploadRun = false;
  sci.Workflow workflow = sci.Workflow();
  
}