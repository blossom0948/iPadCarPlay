#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <sstream>
#include <string>

#include "scssdk_telemetry.h"
#include "common/scssdk_telemetry_common_configs.h"
#include "common/scssdk_telemetry_common_channels.h"
#include "common/scssdk_telemetry_common_gameplay_events.h"
#include "common/scssdk_telemetry_truck_common_channels.h"
#include "eurotrucks2/scssdk_eut2.h"

namespace {

struct FloatField { float value = 0; bool available = false; };
struct IntField { int32_t value = 0; bool available = false; };
struct UIntField { uint32_t value = 0; bool available = false; };
struct BoolField { bool value = false; bool available = false; };
struct StringField { std::string value; bool available = false; };

struct PlacementField {
    double x = 0;
    double y = 0;
    double z = 0;
    double headingDegrees = 0;
    bool available = false;
};

struct TelemetryState {
    FloatField speed;
    FloatField rpm;
    IntField gear;
    IntField nextRestStop;
    IntField nextMandatoryBreak;
    UIntField gameTimeMinutes;
    FloatField fuel;
    FloatField fuelRange;
    FloatField navigationDistance;
    FloatField navigationTime;
    FloatField speedLimit;
    FloatField odometer;
    FloatField engineWear;
    FloatField transmissionWear;
    FloatField cabinWear;
    FloatField chassisWear;
    BoolField parkingBrake;
    BoolField leftIndicator;
    BoolField rightIndicator;
    PlacementField position;
    StringField cargo;
    StringField sourceCity;
    StringField destinationCity;
    StringField destinationCompany;
    double fuelCapacity = 0;
    bool fuelCapacityAvailable = false;
    UIntField deliveryDeadlineGameMinutes;
} state;

scs_log_t gameLog = nullptr;
bool gameActive = false;
bool gamePaused = true;
std::atomic<uint64_t> sequence{0};
uint64_t lastSentAt = 0;
SOCKET udpSocket = INVALID_SOCKET;
sockaddr_in bridgeAddress{};

std::string quote(const std::string& value) {
    std::ostringstream out;
    out << '"';
    for (unsigned char character : value) {
        switch (character) {
        case '"': out << "\\\""; break;
        case '\\': out << "\\\\"; break;
        case '\b': out << "\\b"; break;
        case '\f': out << "\\f"; break;
        case '\n': out << "\\n"; break;
        case '\r': out << "\\r"; break;
        case '\t': out << "\\t"; break;
        default:
            if (character < 0x20) {
                out << "\\u" << std::hex << std::setw(4) << std::setfill('0') << static_cast<int>(character) << std::dec;
            } else {
                out << static_cast<char>(character);
            }
        }
    }
    out << '"';
    return out.str();
}

std::string number(double value, bool available) {
    if (!available || !std::isfinite(value)) return "null";
    std::ostringstream out;
    out << std::setprecision(10) << value;
    return out.str();
}

std::string boolean(const BoolField& field) {
    if (!field.available) return "null";
    return field.value ? "true" : "false";
}

std::string stringValue(const StringField& field) {
    return field.available ? quote(field.value) : "null";
}

void sendJson(const std::string& json) {
    if (udpSocket == INVALID_SOCKET || json.empty()) return;
    sendto(udpSocket, json.c_str(), static_cast<int>(json.size()), 0,
        reinterpret_cast<const sockaddr*>(&bridgeAddress), sizeof(bridgeAddress));
}

std::string buildSnapshot() {
    const auto& p = state.position;
    std::ostringstream out;
    out << "{\"type\":\"telemetry.snapshot\",\"version\":1,\"sequence\":" << ++sequence
        << ",\"data\":{"
        << "\"sequence\":" << sequence.load()
        << ",\"gameActive\":" << (gameActive ? "true" : "false")
        << ",\"paused\":" << (gamePaused ? "true" : "false")
        << ",\"speedMps\":" << number(state.speed.value, state.speed.available)
        << ",\"engineRpm\":" << number(state.rpm.value, state.rpm.available)
        << ",\"gear\":" << (state.gear.available ? std::to_string(state.gear.value) : "null")
        << ",\"nextRestStopMinutes\":" << (state.nextRestStop.available ? std::to_string(state.nextRestStop.value) : "null")
        << ",\"nextMandatoryBreakMinutes\":" << (state.nextMandatoryBreak.available ? std::to_string(state.nextMandatoryBreak.value) : "null")
        << ",\"gameTimeMinutes\":" << (state.gameTimeMinutes.available ? std::to_string(state.gameTimeMinutes.value) : "null")
        << ",\"deliveryDeadlineGameMinutes\":" << (state.deliveryDeadlineGameMinutes.available ? std::to_string(state.deliveryDeadlineGameMinutes.value) : "null")
        << ",\"fuelLiters\":" << number(state.fuel.value, state.fuel.available)
        << ",\"fuelCapacityLiters\":" << number(state.fuelCapacity, state.fuelCapacityAvailable)
        << ",\"fuelRangeKm\":" << number(state.fuelRange.value, state.fuelRange.available)
        << ",\"navigationDistanceMeters\":" << number(state.navigationDistance.value, state.navigationDistance.available)
        << ",\"navigationEtaSeconds\":" << number(state.navigationTime.value, state.navigationTime.available)
        << ",\"navigationSpeedLimitMps\":" << number(state.speedLimit.value, state.speedLimit.available)
        << ",\"odometerKm\":" << number(state.odometer.value, state.odometer.available)
        << ",\"engineWear\":" << number(state.engineWear.value, state.engineWear.available)
        << ",\"transmissionWear\":" << number(state.transmissionWear.value, state.transmissionWear.available)
        << ",\"cabinWear\":" << number(state.cabinWear.value, state.cabinWear.available)
        << ",\"chassisWear\":" << number(state.chassisWear.value, state.chassisWear.available)
        << ",\"parkingBrake\":" << boolean(state.parkingBrake)
        << ",\"leftIndicator\":" << boolean(state.leftIndicator)
        << ",\"rightIndicator\":" << boolean(state.rightIndicator)
        << ",\"worldPosition\":";
    if (p.available) {
        out << "{\"x\":" << number(p.x, true)
            << ",\"y\":" << number(p.y, true)
            << ",\"z\":" << number(p.z, true)
            << ",\"headingDegrees\":" << number(p.headingDegrees, true) << '}';
    } else {
        out << "null";
    }
    out << ",\"cargo\":" << stringValue(state.cargo)
        << ",\"sourceCity\":" << stringValue(state.sourceCity)
        << ",\"destinationCity\":" << stringValue(state.destinationCity)
        << ",\"destinationCompany\":" << stringValue(state.destinationCompany)
        << "}}";
    return out.str();
}

void sendSnapshot() {
    sendJson(buildSnapshot());
    lastSentAt = GetTickCount64();
}

SCSAPI_VOID storeFloat(const scs_string_t, const scs_u32_t, const scs_value_t* const value, const scs_context_t context) {
    auto* field = static_cast<FloatField*>(context);
    field->available = value != nullptr;
    if (value) field->value = value->value_float.value;
}

SCSAPI_VOID storeInt(const scs_string_t, const scs_u32_t, const scs_value_t* const value, const scs_context_t context) {
    auto* field = static_cast<IntField*>(context);
    field->available = value != nullptr;
    if (value) field->value = value->value_s32.value;
}

SCSAPI_VOID storeUInt(const scs_string_t, const scs_u32_t, const scs_value_t* const value, const scs_context_t context) {
    auto* field = static_cast<UIntField*>(context);
    field->available = value != nullptr;
    if (value) field->value = value->value_u32.value;
}

SCSAPI_VOID storeBool(const scs_string_t, const scs_u32_t, const scs_value_t* const value, const scs_context_t context) {
    auto* field = static_cast<BoolField*>(context);
    field->available = value != nullptr;
    if (value) field->value = value->value_bool.value;
}

SCSAPI_VOID storeString(const scs_string_t, const scs_u32_t, const scs_value_t* const value, const scs_context_t context) {
    auto* field = static_cast<StringField*>(context);
    field->available = value && value->value_string.value;
    if (field->available) field->value = value->value_string.value;
    else field->value.clear();
}

SCSAPI_VOID storePosition(const scs_string_t, const scs_u32_t, const scs_value_t* const value, const scs_context_t context) {
    auto* field = static_cast<PlacementField*>(context);
    field->available = value != nullptr;
    if (!value) return;
    field->x = value->value_dplacement.position.x;
    field->y = value->value_dplacement.position.y;
    field->z = value->value_dplacement.position.z;
    field->headingDegrees = value->value_dplacement.orientation.heading * 360.0;
}

void registerFloat(const scs_telemetry_init_params_v101_t* params, const char* name, FloatField* field) {
    params->register_for_channel(name, SCS_U32_NIL, SCS_VALUE_TYPE_float,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storeFloat, field);
}

void registerBool(const scs_telemetry_init_params_v101_t* params, const char* name, BoolField* field) {
    params->register_for_channel(name, SCS_U32_NIL, SCS_VALUE_TYPE_bool,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storeBool, field);
}

std::string attributeString(const scs_named_value_t* attributes, const char* requestedName) {
    if (!attributes) return {};
    for (auto* item = attributes; item->name; ++item) {
        if (std::string(item->name) == requestedName && item->value.type == SCS_VALUE_TYPE_string && item->value.value_string.value) {
            return item->value.value_string.value;
        }
    }
    return {};
}

double attributeNumber(const scs_named_value_t* attributes, const char* requestedName, bool* found) {
    if (found) *found = false;
    if (!attributes) return 0;
    for (auto* item = attributes; item->name; ++item) {
        if (std::string(item->name) != requestedName) continue;
        switch (item->value.type) {
        case SCS_VALUE_TYPE_float:
            if (found) *found = true;
            return item->value.value_float.value;
        case SCS_VALUE_TYPE_double:
            if (found) *found = true;
            return item->value.value_double.value;
        case SCS_VALUE_TYPE_s32:
            if (found) *found = true;
            return item->value.value_s32.value;
        case SCS_VALUE_TYPE_u32:
            if (found) *found = true;
            return item->value.value_u32.value;
        default: return 0;
        }
    }
    return 0;
}

std::string attributeJson(const scs_named_value_t* attributes) {
    std::ostringstream out;
    out << '{';
    bool first = true;
    if (attributes) {
        for (auto* item = attributes; item->name; ++item) {
            if (!first) out << ',';
            first = false;
            out << quote(item->name) << ':';
            const auto& value = item->value;
            switch (value.type) {
            case SCS_VALUE_TYPE_bool: out << quote(value.value_bool.value ? "true" : "false"); break;
            case SCS_VALUE_TYPE_s32: out << quote(std::to_string(value.value_s32.value)); break;
            case SCS_VALUE_TYPE_u32: out << quote(std::to_string(value.value_u32.value)); break;
            case SCS_VALUE_TYPE_s64: out << quote(std::to_string(value.value_s64.value)); break;
            case SCS_VALUE_TYPE_u64: out << quote(std::to_string(value.value_u64.value)); break;
            case SCS_VALUE_TYPE_float: out << quote(number(value.value_float.value, true)); break;
            case SCS_VALUE_TYPE_double: out << quote(number(value.value_double.value, true)); break;
            case SCS_VALUE_TYPE_string: out << quote(value.value_string.value ? value.value_string.value : ""); break;
            default: out << quote("unavailable"); break;
            }
        }
    }
    out << '}';
    return out.str();
}

SCSAPI_VOID onGameplayEvent(const scs_event_t, const void* const eventInfo, const scs_context_t) {
    const auto* info = static_cast<const scs_telemetry_gameplay_event_t*>(eventInfo);
    if (!info || !info->id) return;
    const std::string eventId(info->id);
    const uint64_t nowMs = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count());
    std::ostringstream out;
    out << "{\"type\":\"game.event\",\"version\":1,\"event\":{\"eventId\":" << quote(eventId)
        << ",\"happenedAtUnixMs\":" << nowMs
        << ",\"attributes\":" << attributeJson(info->attributes) << "}}";
    sendJson(out.str());
    if (eventId == SCS_TELEMETRY_GAMEPLAY_EVENT_job_delivered ||
        eventId == SCS_TELEMETRY_GAMEPLAY_EVENT_job_cancelled) {
        state.cargo = {};
        state.sourceCity = {};
        state.destinationCity = {};
        state.destinationCompany = {};
        state.deliveryDeadlineGameMinutes = {};
    }
}

SCSAPI_VOID onConfiguration(const scs_event_t, const void* const eventInfo, const scs_context_t) {
    const auto* info = static_cast<const scs_telemetry_configuration_t*>(eventInfo);
    if (!info || !info->id) return;
    if (std::string(info->id) == SCS_TELEMETRY_CONFIG_truck) {
        bool found = false;
        state.fuelCapacity = attributeNumber(info->attributes, SCS_TELEMETRY_CONFIG_ATTRIBUTE_fuel_capacity, &found);
        state.fuelCapacityAvailable = found;
    }
    if (std::string(info->id) == SCS_TELEMETRY_CONFIG_job) {
        state.cargo.value = attributeString(info->attributes, SCS_TELEMETRY_CONFIG_ATTRIBUTE_cargo);
        state.cargo.available = !state.cargo.value.empty();
        state.sourceCity.value = attributeString(info->attributes, SCS_TELEMETRY_CONFIG_ATTRIBUTE_source_city);
        state.sourceCity.available = !state.sourceCity.value.empty();
        state.destinationCity.value = attributeString(info->attributes, SCS_TELEMETRY_CONFIG_ATTRIBUTE_destination_city);
        state.destinationCity.available = !state.destinationCity.value.empty();
        state.destinationCompany.value = attributeString(info->attributes, SCS_TELEMETRY_CONFIG_ATTRIBUTE_destination_company);
        state.destinationCompany.available = !state.destinationCompany.value.empty();
        bool deadlineFound = false;
        const double deadline = attributeNumber(info->attributes, SCS_TELEMETRY_CONFIG_ATTRIBUTE_delivery_time, &deadlineFound);
        state.deliveryDeadlineGameMinutes.value = deadlineFound && deadline >= 0
            ? static_cast<uint32_t>(deadline)
            : 0;
        state.deliveryDeadlineGameMinutes.available = deadlineFound && deadline >= 0;
    }
}

SCSAPI_VOID onFrameEnd(const scs_event_t, const void*, const scs_context_t) {
    if (!gameActive || gamePaused) return;
    const uint64_t now = GetTickCount64();
    if (now - lastSentAt >= 100) sendSnapshot();
}

SCSAPI_VOID onPauseState(const scs_event_t event, const void*, const scs_context_t) {
    if (event == SCS_TELEMETRY_EVENT_paused) {
        gamePaused = true;
    } else {
        gamePaused = false;
        gameActive = true;
    }
    sendSnapshot();
}

bool initializeUdp() {
    WSADATA data{};
    if (WSAStartup(MAKEWORD(2, 2), &data) != 0) return false;
    udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (udpSocket == INVALID_SOCKET) return false;
    bridgeAddress = {};
    bridgeAddress.sin_family = AF_INET;
    bridgeAddress.sin_port = htons(8766);
    inet_pton(AF_INET, "127.0.0.1", &bridgeAddress.sin_addr);
    return true;
}

} // namespace

extern "C" SCSAPI_RESULT scs_telemetry_init(const scs_u32_t version, const scs_telemetry_init_params_t* const params) {
    if (version != SCS_TELEMETRY_VERSION_1_01) return SCS_RESULT_unsupported;
    const auto* versionParams = static_cast<const scs_telemetry_init_params_v101_t*>(params);
    if (std::string(versionParams->common.game_id) != SCS_GAME_ID_EUT2) return SCS_RESULT_unsupported;
    if (!initializeUdp()) {
        versionParams->common.log(SCS_LOG_TYPE_error, "ETS2 CarPlay: could not open local UDP telemetry socket");
        return SCS_RESULT_generic_error;
    }
    gameLog = versionParams->common.log;

    const bool eventsRegistered =
        versionParams->register_for_event(SCS_TELEMETRY_EVENT_frame_end, onFrameEnd, nullptr) == SCS_RESULT_ok &&
        versionParams->register_for_event(SCS_TELEMETRY_EVENT_paused, onPauseState, nullptr) == SCS_RESULT_ok &&
        versionParams->register_for_event(SCS_TELEMETRY_EVENT_started, onPauseState, nullptr) == SCS_RESULT_ok;
    if (!eventsRegistered) return SCS_RESULT_generic_error;

    versionParams->register_for_event(SCS_TELEMETRY_EVENT_gameplay, onGameplayEvent, nullptr);
    versionParams->register_for_event(SCS_TELEMETRY_EVENT_configuration, onConfiguration, nullptr);

    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_speed, &state.speed);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_engine_rpm, &state.rpm);
    versionParams->register_for_channel(SCS_TELEMETRY_TRUCK_CHANNEL_engine_gear, SCS_U32_NIL, SCS_VALUE_TYPE_s32,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storeInt, &state.gear);
    versionParams->register_for_channel(SCS_TELEMETRY_CHANNEL_next_rest_stop, SCS_U32_NIL, SCS_VALUE_TYPE_s32,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storeInt, &state.nextRestStop);
    versionParams->register_for_channel(SCS_TELEMETRY_CHANNEL_next_mandatory_break, SCS_U32_NIL, SCS_VALUE_TYPE_s32,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storeInt, &state.nextMandatoryBreak);
    versionParams->register_for_channel(SCS_TELEMETRY_CHANNEL_game_time, SCS_U32_NIL, SCS_VALUE_TYPE_u32,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storeUInt, &state.gameTimeMinutes);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_fuel, &state.fuel);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_fuel_range, &state.fuelRange);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_navigation_distance, &state.navigationDistance);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_navigation_time, &state.navigationTime);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_navigation_speed_limit, &state.speedLimit);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_odometer, &state.odometer);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_wear_engine, &state.engineWear);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_wear_transmission, &state.transmissionWear);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_wear_cabin, &state.cabinWear);
    registerFloat(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_wear_chassis, &state.chassisWear);
    registerBool(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_parking_brake, &state.parkingBrake);
    registerBool(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_lblinker, &state.leftIndicator);
    registerBool(versionParams, SCS_TELEMETRY_TRUCK_CHANNEL_rblinker, &state.rightIndicator);
    versionParams->register_for_channel(SCS_TELEMETRY_TRUCK_CHANNEL_world_placement, SCS_U32_NIL, SCS_VALUE_TYPE_dplacement,
        SCS_TELEMETRY_CHANNEL_FLAG_no_value, storePosition, &state.position);

    gamePaused = true;
    gameActive = false;
    gameLog(SCS_LOG_TYPE_message, "ETS2 CarPlay telemetry plugin connected to the local bridge on UDP 8766");
    return SCS_RESULT_ok;
}

extern "C" SCSAPI_VOID scs_telemetry_shutdown(void) {
    if (udpSocket != INVALID_SOCKET) {
        closesocket(udpSocket);
        udpSocket = INVALID_SOCKET;
        WSACleanup();
    }
    gameLog = nullptr;
}
