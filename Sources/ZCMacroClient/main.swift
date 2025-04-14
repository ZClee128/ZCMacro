import ZCMacro
import Foundation

class Base: Codable {
    var age: Int?
}

@zcCodable
class Test: Codable {
//    var name: String?
//    @zcAnnotation(key: ["new_age","age2"],default: 99)
//    var age: Int?
    var type: TestType?
//    @zcAnnotation(key: ["new_add"], default: "aa")
//    var address: String?
//    var optional: Bool?
//    var array: [String]?
    var dic: Any?
    var arr: [Any]?
    @zcAnnotation(default: ZCArchiverBox(NSAttributedString(string: "")), ignore: true)
    var people: ZCArchiverBox<NSAttributedString> = ZCArchiverBox(NSAttributedString(string: ""))
}

enum TestType: Int, ZCCodable {
    static var defaultValue: TestType {
        return .age
    }
    
    case age = 1
    case post = 2
}

//@zcCodable
//struct Generic {
//    var value: Test?
//}

// key不存在 解析
let dic: [String: Any] = ["age": 1, "type": 2, "dic": ["aaa": 11,"bbb": "33"]]

do {
    let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
    let value = try JSONDecoder().decode(Test.self, from: jsonData)
    print(value)
} catch {
    print("Error: \(error)")
}

//let a = 99
//
//@zcCodable
//struct People{
//    //  @icarusAnnotation(default: "aaaad")
//    let name: String
//    //  @icarusAnnotation(key: "new_age", default: a + 1)
//    let age: Int
//    //    @icarusAnnotation(default: Sex.female)
//    let sex: Sex
//}
//
//let peopleDic: [String: Any] = ["name": "ldc", "age": false]
//let testDic: [String: Any] = [:]
//
//do {
//    let value: People = try decode(peopleDic)
//    print(value)
//} catch {
//    print("Error: \(error)")
//}
//
//func decode<T: Codable>(_ dic: [String: Any]) throws -> T {
//    let jsonData = try JSONSerialization.data(withJSONObject: dic, options: [])
//    return try JSONDecoder().decode(T.self, from: jsonData)
//}
//
//@zcMirror
//struct MirrorTest {
//    let name: String
//    let age: Int
//    let people: People
//    let optional: Int?
//}
//
//print(MirrorTest.mirror)
//
//@zcCodable
//struct Address {
//    let country: String
//    let province: String
//    let city: String
//}
//
//enum Sex: ZCCodable {
//    case male
//    case female
//    
//    static var defaultValue: Sex { .male }
//}
//
//@zcCodable
//struct Student {
//    @zcAnnotation(key: ["new_name"])
//    let name: String
//    @zcAnnotation(default: 100)
//    let age: Int
//    let address: Address
//    @zcAnnotation(default: true)
//    let isBoarder: Bool
//    @zcAnnotation(key: ["_sex"], default: Sex.female)
//    let sex: Sex
//}
