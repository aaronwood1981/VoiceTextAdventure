//
//  World.swift
//  VoiceTextAdventure
//
//  Created by Aaron Wood on 2023-06-02.
//

import Foundation

enum Direction : String, Codable {
    case NORTH
    case SOUTH
    case EAST
    case WEST
    
    func opposite() -> Direction {
        switch self {
        case .EAST:
            return .WEST
        case .WEST:
            return .EAST
        case .NORTH:
            return .SOUTH
        case .SOUTH:
            return .NORTH
        }
    }
}

class World : Codable {
    
    enum WorldKeys: CodingKey {
        case rooms
        case doors
        case currentRoomIndex
        case inventory
        case flags
    }
    
    enum WorldErrors: Error {
        case roomWithIndexDoesNotExist
    }
    
    var rooms = [Int : Room]()
    var doors = [Door]()
    var currentRoomIndex = 0
    
    var flags = Set<String>()
    
    var currentRoom : Room {
        get {
            guard let room = rooms[currentRoomIndex] else {
                fatalError("CurrentRoomIndex has a value (\(currentRoomIndex)) for which no room could be found")
            }
            return room
        }
    }
    
    var inventory = [Item]()
    
    init() {
        
    }
    
    required init(from decoder: Decoder) throws {
        
        let values = try decoder.container(keyedBy: WorldKeys.self)
        
        let roomsArray = try values.decode([Room].self, forKey: .rooms)
        roomsArray.forEach {
            room in
            rooms[room.id] = room
        }
        
        doors = try values.decode([Door].self, forKey: .doors)
        inventory = try values.decode([Item].self, forKey: .inventory)
        currentRoomIndex = try values.decode(Int.self, forKey: .currentRoomIndex)
        flags = try values.decode(Set<String>.self, forKey: .flags)
        
        guard currentRoomIndex >= 0 && currentRoomIndex < rooms.count else {
            throw WorldErrors.roomWithIndexDoesNotExist
        }
        
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: WorldKeys.self)
        
        let roomsArray = Array(rooms.values)
        try container.encode(roomsArray, forKey: .rooms)
        try container.encode(doors, forKey: .doors)
        try container.encode(inventory, forKey: .inventory)
        try container.encode(currentRoomIndex, forKey: .currentRoomIndex)
        try container.encode(flags, forKey: .flags)
    }
    
    func saveGame() -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = dir.appending(path: "taSave.json")
                print("attempting save to : \(fileURL)")
                try data.write(to: fileURL, options: .atomic)
                return true
            } else
            {
                return false
            }
        } catch {
            print("Error: \(error)")
            return false
        }
    }
    
    static func loadGame(from url: URL) -> World? {
        var world: World? = nil
        print("attempting to load from: \(url)")
        
        do {
            let decoder = JSONDecoder()
            let data = try Data(contentsOf: url)
            world = try? decoder.decode(World.self, from: data)
            print("Successfully loaded world")
        } catch {
            print("Error: \(error)")
        }
        
        return world
    }
    
    func addRoom(id: Int, name: String, description: String) {
        rooms[id] = Room(id: id, name: name, description: description)
    }
    
    func connectRoomFrom(room: Room, using direction: Direction, to room2: Room, bidirectional: Bool = true)
    {
        rooms[room.id] = room.addExit(direction: direction, roomID: room2.id)
        if bidirectional {
            rooms[room2.id] = room2.addExit(direction: direction.opposite(), roomID: room.id)
        }
    }
    
    func connectRoomFrom(roomId: Int, using direction: Direction, to room2Id: Int, bidirectional: Bool = true)
    {
        guard let room1 = rooms[roomId], let room2 = rooms[room2Id] else {
            print("At least one room could not be found")
            return
        }
        connectRoomFrom(room: room1, using: direction, to: room2, bidirectional: bidirectional)
    }
    
    func go(direction: Direction) -> Bool {
        if currentRoom.exits.keys.contains(direction) {
            currentRoomIndex = currentRoom.exits[direction]!
            return true
        }
        else {
            return false
        }
    }
    
    func take(item: Item) -> Bool {
        if currentRoom.items.contains(item) {
            rooms[currentRoomIndex] = currentRoom.removeItem(item)
            inventory.append(item)
            return true
        }
        else
        {
            return false
        }
    }
    
    func open(door: Door) -> Door.DoorResult {
        guard doorsInRoom(room: currentRoom).contains(door) else {
            return Door.DoorResult.doorDoesNotExist
        }
        
        let result = door.open(world: self)
        if result == .doorDidOpen {
            doors.remove(at: doors.firstIndex(of: door)!)
        }
        return result
    }
    
    func use(item: Item) -> Item.ItemResult {
        guard let effect = item.effect else {
            return Item.ItemResult.noEffect
        }
        
        switch effect {
        case .light:
            flags.insert("light")
            return .itemHadEffect
        }
    }
    
    func use(item: Item, with indirectItem: Item) -> Item.ItemResult {
        guard item.combineItemName == indirectItem.name else {
            return .itemsCannotBeCombined
        }
        
        guard indirectItem.combineItemName == item.name else {
            return .itemsCannotBeCombined
        }
        
        guard let replaceItemName = item.replaceWithAfterUse else {
            return .itemsCannotBeCombined
        }
        
        if let newItem = Item.prototypes.first(where: {
            item in item.name == replaceItemName
        }){
            if let itemIndex = inventory.firstIndex(of: item) {
                inventory.remove(at: itemIndex)
            }
            
            if let itemIndex = inventory.firstIndex(of: indirectItem) {
                inventory.remove(at: itemIndex)
            }
            
            inventory.append(newItem)
            
            return .itemHadEffect
        }
        return .itemHadNoEffect
    }
    
    func doorsInRoom(room: Room) -> [Door] {
        return doors.filter { $0.betweenRooms.keys.contains(room.id)}
    }
}
