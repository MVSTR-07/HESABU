# HESABU privacy summary

I designed HESABU so business records stay on the user's device. Imported
statements, transactions, customers, reports and analysis results are stored in
an encrypted local database. HESABU does not upload business records to a
server.

The production account service will store only the account identifier/email,
subscription entitlement and billing-provider identifiers needed to verify a
plan. It will not store statements, transactions, customer lists or reports.

The current build uses a clearly labelled local demo account. It collects no
password and is not real authentication. Production authentication and Google
Play Billing will be connected only after their provider projects are created
and their configuration is reviewed.

Users can clear cached business data or delete all local HESABU data from
Settings. Account deletion in production will remove the account metadata held
by the account service as well as the local encrypted workspace. Original files
selected for import remain wherever the user chose to keep them unless the user
deletes those files separately.

The optional AI controls are off by default. This build has no AI provider,
endpoint, API key or network client. If I connect an AI provider in a later
release, HESABU will show the purpose, provider and exact minimised payload
before every request. A fresh approval is bound to that exact payload; changing
the summary, purpose, provider or listed fields requires fresh consent. The
base product remains fully usable without AI.
