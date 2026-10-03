/*
 Original StatBatt fixed CHIE restore-only lab. No arbitrary key or payload entry point.
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
#include "StatBattAdapterControl.h"
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
/* Source-only preparation. No disconnect/guardian mode can execute in this build. */
#define SB_ADAPTER_CONTROL_ENABLED 0
#define SB_ADAPTER_RECOVERY_ENABLED 0
enum { WIRE_SIZE = 80, KEY_OFFSET = 0, SIZE_OFFSET = 28, TYPE_OFFSET = 32,
       ATTR_OFFSET = 36, RESULT_OFFSET = 40, STATUS_OFFSET = 41,
       COMMAND_OFFSET = 42, VALUE_OFFSET = 48 };
static uint32_t word(const uint8_t *b, size_t n) { uint32_t v; memcpy(&v,b+n,4); return v; }
static void put(uint8_t *b,size_t n,uint32_t v) { memcpy(b+n,&v,4); }
static int exchange(io_connect_t port,uint8_t command,uint8_t disconnect,SBAdapterStep *step,uint8_t response[WIRE_SIZE]) {
    uint8_t request[WIRE_SIZE] = {0};
    memset(response,0,WIRE_SIZE);
    put(request,KEY_OFFSET,0x43484945); /* CHIE only */
    if(command != 9) put(request,SIZE_OFFSET,1);
    request[COMMAND_OFFSET]=command;
    /* Only fixed zero restoration or fixed adapter inhibition; no caller payload. */
    if(command == 6 && disconnect == 1) request[VALUE_OFFSET] = 0x08;
    size_t size=WIRE_SIZE;
    step->attempted=1;
    step->transport=IOConnectCallStructMethod(port,2,request,WIRE_SIZE,response,&size);
    step->length=(uint32_t)size;
    if(step->transport != 0 || size != WIRE_SIZE) return 0;
    step->smc_result=response[RESULT_OFFSET]; step->smc_status=response[STATUS_OFFSET];
    return step->smc_result == 0 && step->smc_status == 0;
}
SBAdapterReport sb_adapter_control(uint8_t restore_requested) {
    SBAdapterReport r={0};
#if !defined(__arm64__)
    r.outcome=9; return r;
#else
    if((restore_requested!=0 && restore_requested!=3 && restore_requested!=4) || (restore_requested==3 && (!SB_ADAPTER_CONTROL_ENABLED || !SB_ADAPTER_RECOVERY_ENABLED)) || (restore_requested==4 && !SB_ADAPTER_RECOVERY_ENABLED) || getuid()!=0 || geteuid()!=0) { r.outcome=9; return r; }
    io_service_t service=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("AppleSMC"));
    if(service==IO_OBJECT_NULL) { r.outcome=1; r.service_open=kIOReturnNotFound; return r; }
    io_connect_t port=IO_OBJECT_NULL;
    r.service_open_attempted=1;
    r.service_open=IOServiceOpen(service,mach_task_self(),1,&port);
    IOObjectRelease(service);
    if(r.service_open != 0 || port==IO_OBJECT_NULL) { r.outcome=1; return r; }
    r.client_open_attempted=1;
    r.client_open=IOConnectCallMethod(port,0,NULL,0,NULL,0,NULL,NULL,NULL,NULL);
    if(r.client_open != 0) { r.outcome=1; goto close_service; }
    uint8_t response[WIRE_SIZE];
    if(!exchange(port,9,0,&r.metadata,response)) { r.outcome=2; goto close_client; }
    r.data_size=word(response,SIZE_OFFSET); r.data_type=word(response,TYPE_OFFSET); r.attributes=response[ATTR_OFFSET];
    if(r.data_size!=1 || r.data_type!=0x6865785f || r.attributes!=0xD4) { r.outcome=3; goto close_client; }
    if(!exchange(port,5,0,&r.baseline,response)) { r.outcome=4; goto close_client; }
    r.baseline_value=response[VALUE_OFFSET];
    if(!restore_requested) goto close_client;
    if(r.baseline_value!=0 && !(restore_requested==4 && r.baseline_value==0x08)) { r.outcome=5; goto close_client; }
    if(!exchange(port,6,restore_requested==3,&r.restore,response)) { r.outcome=6; goto close_client; }
    if(!exchange(port,5,0,&r.readback,response)) { r.outcome=7; goto close_client; }
    r.readback_value=response[VALUE_OFFSET];
    if(r.readback_value!=(restore_requested==3 ? 0x08 : 0)) r.outcome=8;
close_client:
    r.client_close_attempted=1;
    r.client_close=IOConnectCallMethod(port,1,NULL,0,NULL,0,NULL,NULL,NULL,NULL);
close_service:
    r.service_close_attempted=1; r.service_close=IOServiceClose(port);
    if(r.outcome==0 && (r.client_close!=0 || r.service_close!=0)) r.outcome=10;
    return r;
#endif
}

/* Idle sleep assertion: does not promise to prevent explicit sleep, lid closure,
   shutdown, kernel failure or firmware persistence. Pair with immediate restore. */
uint32_t sb_control_prevent_idle_sleep(uint32_t *assertion) {
    if(!SB_ADAPTER_CONTROL_ENABLED || getuid()!=0 || geteuid()!=0) return kIOReturnNotPermitted;
    return IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep,
        kIOPMAssertionLevelOn, CFSTR("StatBatt bounded adapter recovery"), assertion);
}
uint32_t sb_control_release_idle_sleep(uint32_t assertion) {
    return IOPMAssertionRelease(assertion);
}
void sb_control_ignore_broken_output(void) { signal(SIGPIPE, SIG_IGN); }
