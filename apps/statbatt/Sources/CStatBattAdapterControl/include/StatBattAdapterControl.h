#ifndef STATBATT_ADAPTER_CONTROL_H
#define STATBATT_ADAPTER_CONTROL_H
#include <stdint.h>
typedef struct {
    uint32_t transport, length;
    uint8_t attempted, smc_result, smc_status;
} SBAdapterStep;
typedef struct {
    uint32_t service_open, client_open, client_close, service_close;
    uint8_t service_open_attempted, client_open_attempted, client_close_attempted, service_close_attempted;
    SBAdapterStep metadata, baseline, restore, readback;
    uint32_t data_size, data_type;
    uint8_t attributes, baseline_value, readback_value;
    /* 0 success, 1 connection, 2 metadata, 3 layout, 4 baseline, 5 unexpected baseline,
       6 restore call, 7 readback, 8 unexpected readback, 9 unsupported/identity mismatch, 10 closure. */
    uint8_t outcome;
} SBAdapterReport;
/* Closed root-only CHIE:0 inspect,3 fixed08 from00,4 fixed00 from00or08.
   No arbitrary keys or values. Write modes hard-disabled pending qualification. */
SBAdapterReport sb_adapter_control(uint8_t restore_requested);
uint32_t sb_control_prevent_idle_sleep(uint32_t *assertion);
uint32_t sb_control_release_idle_sleep(uint32_t assertion);
void sb_control_ignore_broken_output(void);
#endif
