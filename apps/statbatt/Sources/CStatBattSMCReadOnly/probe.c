/*
 Original StatBatt read-only diagnostic. No write command or payload entry point.
 ABI field offsets derive from the permissive go-smc interface:
 https://github.com/caseymrm/go-smc/blob/4a31024c8b631d9a241ee3d21a83f94db966605e/smc.h
 Closed key layouts derive from Battery Toolkit's BSD Swift reference:
 https://github.com/mhaeuser/Battery-Toolkit/blob/ed3adf103abfdad53223ce6f0a764ae7163c385b/Libraries/SMCComm%2BPower.swift
 Its APSL SMCParamStruct header is NOT incorporated.

 MIT License
 Copyright (c) 2018 Casey Muller
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 BSD 3-Clause License
 Copyright (C) 2022, Marvin Häuser
 All rights reserved.
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.
 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#include "StatBattSMCReadOnly.h"
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <string.h>

enum { WIRE_SIZE = 80, KEY_OFFSET = 0, SIZE_OFFSET = 28, TYPE_OFFSET = 32,
       ATTR_OFFSET = 36, RESULT_OFFSET = 40, STATUS_OFFSET = 41,
       COMMAND_OFFSET = 42, VALUE_OFFSET = 48 };
typedef struct { const char key[5]; uint32_t size; const char type[5]; } Layout;
/* Size zero means metadata ONLY, regardless of what the device reports. */
static const Layout catalog[SB_SMC_PROBE_KEY_COUNT] = {
    { "CHTE", 4, "ui32" }, { "CH0C", 1, "hex_" },
    { "CHIE", 1, "hex_" }, { "CH0J", 1, "ui8 " },
    { "CH0B", 0, "" }, { "bfF0", 0, "" },
    { "bfD0", 0, "" }, { "bfE0", 0, "" }
};
static uint32_t fourcc(const char *text) {
    return ((uint32_t)(uint8_t)text[0] << 24) | ((uint32_t)(uint8_t)text[1] << 16)
         | ((uint32_t)(uint8_t)text[2] << 8) | (uint8_t)text[3];
}
static uint32_t word(const uint8_t *bytes, size_t offset) {
    uint32_t value; memcpy(&value, bytes + offset, sizeof(value)); return value;
}
static void put_word(uint8_t *bytes, size_t offset, uint32_t value) {
    memcpy(bytes + offset, &value, sizeof(value));
}

SBReadOnlyConnectionObservation sb_smc_read_only_probe(SBReadOnlyKeyObservation observations[SB_SMC_PROBE_KEY_COUNT]) {
    SBReadOnlyConnectionObservation connection = {0};
    memset(observations, 0, sizeof(SBReadOnlyKeyObservation) * SB_SMC_PROBE_KEY_COUNT);
#if !defined(__arm64__)
    connection.service_open_return = (uint32_t)kIOReturnUnsupported;
    return connection;
#else
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) {
        connection.service_open_return = (uint32_t)kIOReturnNotFound;
        return connection;
    }
    io_connect_t port = IO_OBJECT_NULL;
    connection.service_open_return = (uint32_t)IOServiceOpen(service, mach_task_self(), 1, &port);
    IOObjectRelease(service);
    if (connection.service_open_return != 0 || port == IO_OBJECT_NULL) {
        if (connection.service_open_return == 0) connection.service_open_return = (uint32_t)kIOReturnNotOpen;
        return connection;
    }
    /* User-client lifecycle selectors 0/1; neither is an SMC key write. */
    connection.client_open_return = (uint32_t)IOConnectCallMethod(port, 0, NULL, 0, NULL, 0, NULL, NULL, NULL, NULL);
    if (connection.client_open_return == 0) {
        for (uint32_t index = 0; index < SB_SMC_PROBE_KEY_COUNT; ++index) {
            SBReadOnlyKeyObservation *row = &observations[index];
            row->catalog_index = index;
            uint8_t request[WIRE_SIZE] = {0}, response[WIRE_SIZE] = {0};
            put_word(request, KEY_OFFSET, fourcc(catalog[index].key));
            request[COMMAND_OFFSET] = 9; /* metadata only */
            size_t received = WIRE_SIZE;
            row->metadata_return = (uint32_t)IOConnectCallStructMethod(port, 2, request, WIRE_SIZE, response, &received);
            row->metadata_length = (uint32_t)received;
            ++connection.observed_count;
            if (row->metadata_return != 0 || received != WIRE_SIZE) continue;
            row->metadata_result = response[RESULT_OFFSET];
            row->metadata_status = response[STATUS_OFFSET];
            if (row->metadata_result != 0) continue;
            row->data_size = word(response, SIZE_OFFSET);
            row->data_type = word(response, TYPE_OFFSET);
            row->attributes = response[ATTR_OFFSET];
            /* Metadata validity does NOT establish a writable or safe backend. */
            if (catalog[index].size == 0 || row->data_size != catalog[index].size
                || row->data_type != fourcc(catalog[index].type) || row->attributes != 0xD4) continue;
            memset(request, 0, WIRE_SIZE); memset(response, 0, WIRE_SIZE);
            put_word(request, KEY_OFFSET, fourcc(catalog[index].key));
            put_word(request, SIZE_OFFSET, catalog[index].size);
            request[COMMAND_OFFSET] = 5; /* read only */
            row->read_attempted = 1; received = WIRE_SIZE;
            row->read_return = (uint32_t)IOConnectCallStructMethod(port, 2, request, WIRE_SIZE, response, &received);
            row->read_length = (uint32_t)received;
            if (row->read_return != 0 || received != WIRE_SIZE) continue;
            row->read_result = response[RESULT_OFFSET]; row->read_status = response[STATUS_OFFSET];
            if (row->read_result != 0) continue;
            row->value_count = (uint8_t)catalog[index].size;
            memcpy(row->value, response + VALUE_OFFSET, row->value_count);
        }
        connection.client_close_return = (uint32_t)IOConnectCallMethod(port, 1, NULL, 0, NULL, 0, NULL, NULL, NULL, NULL);
    }
    connection.service_close_return = (uint32_t)IOServiceClose(port);
    return connection;
#endif
}
