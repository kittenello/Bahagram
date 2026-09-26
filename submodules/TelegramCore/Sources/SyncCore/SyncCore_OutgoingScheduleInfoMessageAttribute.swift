import Foundation
import Postbox

public let scheduleWhenOnlineTimestamp: Int32 = 0x7ffffffe
public let ghostScheduledMessageDelay: Int32 = 11

public class OutgoingScheduleInfoMessageAttribute: MessageAttribute {
    public let scheduleTime: Int32
    public let repeatPeriod: Int32?
    public let isGhostScheduled: Bool
    
    public init(scheduleTime: Int32, repeatPeriod: Int32?, isGhostScheduled: Bool = false) {
        self.scheduleTime = scheduleTime
        self.repeatPeriod = repeatPeriod
        self.isGhostScheduled = isGhostScheduled
    }
    
    required public init(decoder: PostboxDecoder) {
        self.scheduleTime = decoder.decodeInt32ForKey("t", orElse: 0)
        self.repeatPeriod = decoder.decodeOptionalInt32ForKey("rp")
        self.isGhostScheduled = decoder.decodeBoolForKey("g", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.scheduleTime, forKey: "t")
        if let repeatPeriod = self.repeatPeriod {
            encoder.encodeInt32(repeatPeriod, forKey: "rp")
        } else {
            encoder.encodeNil(forKey: "rp")
        }
        encoder.encodeBool(self.isGhostScheduled, forKey: "g")
    }

    public func effectiveScheduleTime(currentTime: Double) -> Int32 {
        // Telegram sends dates less than 10 seconds away immediately. Leave half
        // a second for transit, and refresh the date after any media upload.
        return self.isGhostScheduled ? max(self.scheduleTime, Int32(ceil(currentTime + 10.5))) : self.scheduleTime
    }
    
    public func withUpdatedScheduleTime(_ scheduleTime: Int32) -> OutgoingScheduleInfoMessageAttribute {
        return OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime, repeatPeriod: self.repeatPeriod, isGhostScheduled: self.isGhostScheduled)
    }
    
    public func withUpdatedRepeatPeriod(_ repeatPeriod: Int32?) -> OutgoingScheduleInfoMessageAttribute {
        return OutgoingScheduleInfoMessageAttribute(scheduleTime: self.scheduleTime, repeatPeriod: repeatPeriod, isGhostScheduled: self.isGhostScheduled)
    }
}

public extension Message {
    var scheduleTime: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                return attribute.scheduleTime
            }
        }
        return nil
    }
    
    var scheduleRepeatPeriod: Int32? {
        for attribute in self.attributes {
            if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                return attribute.repeatPeriod
            } else if let attribute = attribute as? ScheduledRepeatAttribute {
                return attribute.repeatPeriod
            }
        }
        return nil
    }
}
