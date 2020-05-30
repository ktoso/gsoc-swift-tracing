
import Logging
import ContextPropagation

let treeTrunks: TreeTrunksLogging = TreeTrunksLogging(wrap: StreamLogHandler.standardError(label: "tree-trunks"))

LoggingSystem.bootstrap { label in
    treeTrunks
}

var log = Logger(label: "hello")
log.logLevel = .trace

func handleThings(log: Logger) {
    log.info("Hello", metadata: ["x": "value"])
    log.debug("Debug hello", metadata: ["x": "value"])
    log.trace("Started processing path", metadata: ["x": "value", "r": "/path"])
    log.trace("Replying to path", metadata: ["x": "value", "r": "/path"])
}

print("// ==== ----------------------------------------------------------------------------------------------------------------")

handleThings(log: log)
// logs:
// 2020-05-30T12:31:57+0900 info: x=value Hello

print("// ==== ----------------------------------------------------------------------------------------------------------------")
print("// configure: [r=/path]=warning")

//treeTrunks.configure(matcher:
//    .init(.metadataQuery(["r"], "/path"), level: .warning)
//)
try treeTrunks.configure("['r'='/path']=warning")

handleThings(log: log)
// logs:
// 2020-05-30T12:31:57+0900 info: x=value Hello
