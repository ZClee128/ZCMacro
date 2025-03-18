# ZCMacro

[![CocoaPods Version](https://img.shields.io/cocoapods/v/ZCMacro.svg)](https://cocoapods.org/pods/ZCMacro)
Swift宏扩展库，提供`Codable`和`Mirror`协议的自动化实现

## 功能特性
- @zcCodable：自动生成`Codable`协议实现
- @zcMirror：自动生成类型反射信息
- @zcAnnotation：支持自定义编解码键和默认值
- @zcInherit：支持继承Codable协议的子类

## 安装

### Swift Package Manager
```swift
.package(url: "https://github.com/ZClee128/ZCMacro.git", from: "1.0.0")
```

### CocoaPods
```ruby
pod 'ZCMacro'
```

## 使用示例
### 基础使用
```swift
@zcCodable
struct Profile {
    @zcAnnotation(key: "user_name", default: "anonymous")
    var username: String
    
    @zcAnnotation(ignore: true)
    var temporaryID: Int?
}
```

### 继承处理
```swift
class BaseModel: Codable {
    // 已有Codable实现
}

@zcInherit
class User: BaseModel {
    @zcAnnotation(key: ["user", "username"], default: "guest")
    var name: String
}
```

### 类型转换
```swift
@zcCodable
class Product {
    // 字典类型处理
    @zcAnnotation(default: [:]) 
    var attributes: [String: Any]
    
    // 数组类型处理
    @zcAnnotation(default: [])
    var tags: [Any]
}
```

### 多键映射配置
```swift
@zcCodable
class Order {
    @zcAnnotation(key: ["order_id", "id"], default: UUID().uuidString)
    var orderID: String
    
    @zcAnnotation(key: "items", default: [Item]())
    var orderItems: [Item]
}
```

## API文档
### @zcAnnotation 参数
- `key`: 自定义编解码键（支持字符串或数组）
- `default`: 默认值（支持表达式）
- `ignore`: 是否忽略该属性

## 贡献
欢迎通过Issue提交问题或PR提交改进，请遵循现有代码风格。