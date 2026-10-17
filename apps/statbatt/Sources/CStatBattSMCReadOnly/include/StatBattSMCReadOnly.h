#ifndef STATBATT_SMC_READ_ONLY_H
#define STATBATT_SMC_READ_ONLY_H
#include <stdint.h>
#include <stddef.h>

/* Closed diagnostic catalog, never accepts a key, payload, or command. */
enum { SB_SMC_PROBE_KEY_COUNT = 8 };
typedef struct {
    uint32_t catalog_index;
    uint32_t metadata_return;
    uint32_t metadata_length;
    uint32_t data_size;
    uint32_t data_type;
    uint8_t attributes;
    uint8_t metadata_result;
    uint8_t metadata_status;
    uint8_t read_attempted;
    uint32_t read_return;
    uint32_t read_length;
    uint8_t read_result;
    uint8_t read_status;
    uint8_t value_count;
    uint8_t value[4];
} SBReadOnlyKeyObservation;
typedef struct {
    uint32_t service_open_return;
    uint32_t client_open_return;
    uint32_t client_close_return;
    uint32_t service_close_return;
    uint32_t observed_count;
} SBReadOnlyConnectionObservation;

SBReadOnlyConnectionObservation sb_smc_read_only_probe(SBReadOnlyKeyObservation observations[SB_SMC_PROBE_KEY_COUNT]);
#endif
