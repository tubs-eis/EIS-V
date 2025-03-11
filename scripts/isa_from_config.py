import os

CONFIG = os.environ["EISV_CONFIG"]

M_enabled = CONFIG[0] == '1'

isa = 'i'
if M_enabled:
    isa += "m"

print(isa)
