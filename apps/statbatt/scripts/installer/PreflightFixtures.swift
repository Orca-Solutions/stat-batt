// Concatenated with the actual preflight under PREFLIGHT_TESTING. No process,
// filesystem admission, service, or hardware functions are called.
func json(_ object: [String: Any]) -> Data { try! JSONSerialization.data(withJSONObject: object) }
func rejects(_ operation: () throws -> Void) {
    do { try operation(); fatalError("Unsafe fixture was accepted") } catch { }
}
let uuid = "11111111-1111-1111-1111-111111111111"
let validRecord: [String: Any] = ["version": 1, "phase": "restored", "operationID": uuid, "sessionID": uuid, "originatingBootID": uuid, "restorationBootID": uuid, "intendedAt": 10, "restorationFloor": 20, "recoveredAt": 30]
try validateRecord(json(validRecord))
for (key, value) in [("version", 2 as Any), ("phase", "restorationIntent"), ("recoveredAt", 19), ("restorationBootID", "invalid"), ("intendedAt", -1)] {
    var record = validRecord; record[key] = value
    rejects { try validateRecord(json(record)) }
}
var missing = validRecord; missing.removeValue(forKey: "restorationFloor")
rejects { try validateRecord(json(missing)) }
let validInspection: [String: Any] = ["phase": "inspection", "key": 0, "outcome": 0, "adapter": true, "sampledAt": 3_000_000_000, "sourceAt": 3_000_000_000]
try validateInspection(json(validInspection), now: 4_000_000_000)
for (key, value) in [("key", 8 as Any), ("outcome", 1), ("adapter", false), ("sampledAt", 1), ("sourceAt", 5_000_000_000)] {
    var packet = validInspection; packet[key] = value
    rejects { try validateInspection(json(packet), now: 4_000_000_000) }
}
rejects { try validateInspection(json(validInspection) + Data([10]) + json(validInspection), now: 4_000_000_000) }
print("Installer fixture checks passed: restored-record schema and fresh zero/AC inspection.")

try validateClearedNativeRequest(json(["version": 1]))
try validateClearedNativeRequest(json(["version": 1, "connection": NSNull()]))
for record: [String: Any] in [
    ["version": 1, "connection": uuid],
    ["version": 2, "connection": NSNull()],
    ["version": 1, "connection": "invalid"],
    ["version": 1, "connection": 42],
    ["connection": NSNull()]
] { rejects { try validateClearedNativeRequest(json(record)) } }
print("Native-request fixtures passed: only version1 cleared records accepted.")
