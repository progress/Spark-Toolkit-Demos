#
# Primary Recovery Area
b .
#
# After-Image Area
a .
#
# Schema Area (System Tables)
# Using 32 for 1/2/4K DB Block Sizes
d "Schema Area":6,32;1 .
#
# Default Data Area for Application
d "Data Area":10,256;512 .
#
# Default Index Area for Application
d "Index Area":20,1;64 .
#
# Default LOB Area for Application
d "LOB Area":30,1;512 .
#
# Area for Audit Data
d "Audit Data Area":52,256;512 .
#
# Area for Audit Indexes
d "Audit Index Area":54,1;64 .
#
# Data Area for Change Tracking
d "Change Data Area":56,256;512 .
#
# Index Area for Change Tracking
d "Change Index Area":58,1;64 .
#
# Transparent Data Encryption Policy Area
e "Encryption Policy Area":60,32;64 .
#
# Transaction Log for 2-Phase Commit
t . f 1280
