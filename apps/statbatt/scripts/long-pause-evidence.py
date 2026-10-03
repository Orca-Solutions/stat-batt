"""Offline acceptance of a bounded long-pause trace; never launches hardware.

Receipt times must come from the supervising process's continuous clock. This
checks observed duration and restoration, not a hardware-enforced deadline.
"""
import math


def qualifies(events, guardian_exit, final_inspection, fallback_used, journal_restored):
    if guardian_exit != 0 or fallback_used or not journal_restored:
        return False
    if not isinstance(events, list) or not 3 <= len(events) <= 2000:
        return False
    inhibited = []
    last_receipt = 0
    worker_restoring = False
    worker_restored = None
    worker_reaped = False
    for event in events:
        if not isinstance(event, dict): return False
        received, packet = event.get('receivedAt'), event.get('packet')
        if type(received) is not int or received <= last_receipt or not isinstance(packet, dict): return False
        last_receipt = received
        if packet.get('failure') is not None: return False
        phase = packet.get('phase')
        if phase == 'workerRestoring':
            if worker_restoring or worker_reaped or packet.get('recoveryCause') not in ('deadline', 'ownerEOF'): return False
            worker_restoring = True
        elif phase == 'restored' and not worker_reaped:
            if not worker_restoring: return False
            sampled, source = packet.get('sampledAt'), packet.get('sourceAt')
            if (type(sampled) is int and type(source) is int and 0 < sampled <= source <= received
                    and received - sampled <= 2_000_000_000 and packet.get('outcome') == 0
                    and packet.get('key') == 0 and packet.get('adapter') is True and packet.get('battery') is False):
                worker_restored = packet
        elif phase == 'writerReaped':
            if worker_reaped or worker_restored is None or packet.get('reaped') is not True: return False
            worker_reaped = True
        if phase != 'inhibited': continue
        if worker_restoring: return False
        sampled, source = packet.get('sampledAt'), packet.get('sourceAt')
        if (type(sampled) is not int or type(source) is not int
                or not 0 < sampled <= source <= received
                or received - sampled > 250_000_000
                or packet.get('outcome') != 0 or packet.get('key') != 8
                or packet.get('holdSeconds') != 120): return False
        if inhibited and sampled <= inhibited[-1]['sampledAt']: return False
        inhibited.append(packet)
    if not inhibited or not worker_reaped or worker_restored is None: return False
    start = inhibited[0]['sampledAt']
    # Permit normal sampling granularity near the fixed120s deadline. A short
    # early restoration cannot qualify the longer mode.
    if not 119_000_000_000 <= inhibited[-1]['sampledAt'] - start <= 121_000_000_000: return False
    if not inhibited[-1]['sampledAt'] <= worker_restored['sampledAt'] <= worker_restored['sourceAt'] <= start + 125_000_000_000: return False
    previous = start
    for packet in inhibited:
        at = packet['sampledAt']
        if at - previous > 500_000_000: return False
        previous = at
        if at - start >= 2_000_000_000 and not (packet.get('battery') is True and packet.get('adapter') is False): return False
        reserve = packet.get('stateOfCharge')
        if type(reserve) not in (int, float) or not math.isfinite(reserve) or not 50 <= reserve <= 100: return False
    if not isinstance(final_inspection, dict) or final_inspection.get('exit') != 0: return False
    packet = final_inspection.get('packet', {})
    if not isinstance(packet, dict): return False
    received = final_inspection.get('receivedAt')
    sampled, source = packet.get('sampledAt'), packet.get('sourceAt')
    return (type(received) is int and type(sampled) is int and type(source) is int
            and last_receipt <= sampled <= source <= received
            and source - start <= 125_000_000_000
            and received - sampled <= 2_000_000_000
            and packet.get('phase') == 'inspection' and packet.get('outcome') == 0
            and packet.get('key') == 0 and packet.get('adapter') is True and packet.get('battery') is False)
