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

The optional AI add-on is disabled. No business data is sent to an AI provider
without an explicit consent dialog describing exactly what would be sent.
