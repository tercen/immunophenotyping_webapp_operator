import 'package:sci_tercen_client/sci_client_service_factory.dart' as tercen;
import 'package:sci_http_client/http_auth_client.dart' as auth_http;
import 'package:sci_http_client/http_browser_client.dart' as io_http;
import 'package:sci_tercen_client/sci_client.dart' as sci;
import 'package:tson/tson.dart' as tson;



bool get isDev => Uri.base.hasPort && (Uri.base.port > 10000);

Future<bool> initFactory() async {
  var token = Uri.base.queryParameters["token"] ?? '';
  var taskId = Uri.base.queryParameters["taskId"] ?? '';

  if (token.isEmpty) {
    throw "A token is required";
  }

  if (taskId.isEmpty) {
    throw "A taskId is required";
  }

  var authClient =
  auth_http.HttpAuthClient(token, io_http.HttpBrowserClient());

  var factory = sci.ServiceFactory();

  if (isDev) {
    await factory.initializeWith(
        Uri.parse('http://127.0.0.1:5400'), authClient);
  } else {
    var uriBase = Uri.base;
    await factory.initializeWith(
        Uri(scheme: uriBase.scheme, host: uriBase.host, port: uriBase.port),
        authClient);
  }

  tercen.ServiceFactory.CURRENT = factory;

  return true;
}


Future<void> uploadTable(
      sci.Table table, String filename, String projectId, String owner, String folderId) async {
    var factory = tercen.ServiceFactory();
    var bytes = tson.encode(table.toJson());

    var resultFile = sci.FileDocument()
      ..name = table.properties.name
      ..isHidden = true
      ..isTemp = true
      ..folderId = folderId
      ..projectId = projectId
      ..acl.owner = owner;

    resultFile = await factory.fileService
        .upload(resultFile, Stream.fromIterable([bytes]));

    var csvTask = sci.CSVTask()
      ..state = sci.InitState()
      ..owner = owner
      ..projectId = projectId
      ..fileDocumentId = resultFile.id;

    csvTask = await factory.taskService.create(csvTask) as sci.CSVTask;

    await factory.taskService.runTask(csvTask.id);
    await factory.taskService.waitDone(csvTask.id);

    // csvTask = await factory.taskService.get(csvTask.id) as sci.CSVTask;

    // var schema = await factory.tableSchemaService.get(csvTask.schemaId);

    // var computedSchema = sci.ComputedTableSchema()
    //   ..nRows = schema.nRows
    //   ..projectId = task.projectId
    //   ..acl.owner = task.owner
    //   ..name = table.properties.name
    //   ..query = task.query.copy()
    //   ..dataDirectory = schema.dataDirectory;

    // for (var column in schema.columns) {
    //   computedSchema.columns.add(column.copy());
    // }

    // computedSchema = await factory.tableSchemaService.create(computedSchema)
    //     as sci.ComputedTableSchema;

    // await factory.tableSchemaService.delete(schema.id, schema.rev);

    // return computedSchema;
  }