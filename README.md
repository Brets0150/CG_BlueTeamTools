# CG BlueTeamTools

My collection of Bule Team related tools.

```graph TD;

A[Initialize Pwn2Crack] -->|Initialize variables| B[Check if hcxtools is available]

B -->|Yes| C[Check hcxtools version]

C -->|Compatible| D[Enable plugin]
C -->|Not compatible| E[Disable plugin]

B -->|No| E[Disable plugin]

D -->|On handshake capture| F[Check if plugin is running]

F -->|Yes| G[Set hash output filename]
F -->|No| X[End]

G -->|Check if hashes are uploaded| H[If uploaded, skip]
G -->|If not uploaded| I[Confirm pcap is valid handshake]

I -->|Yes| J[Convert pcap to hashcat 22000 hash]
I -->|No| K[Delete pcap file]

J -->|Check if hash file is created| L[If created, continue]
J -->|If not created| K[Delete pcap file]

L -->|Generate wordlist| M[If enabled, generate wordlist]
L -->|Skip wordlist generation| N[End]

M -->|Check if wordlist file is created| O[If created, continue]
M -->|If not created| N[End]

O -->|Upload hashes to Hashtopolis| P[Upload hashes]

P -->|Success| Q[Rename file to indicate upload]
P -->|Failure| R[Log error]

Q -->|Upload wordlist| S[If enabled, upload wordlist]
Q -->|Skip wordlist upload| T[End]

S -->|Success| U[Rename file to indicate upload]
S -->|Failure| V[Log error]

T --> V[Log error]

X --> V[Log error]

E --> V[Log error]```
