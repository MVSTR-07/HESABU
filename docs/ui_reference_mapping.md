# HESABU UI reference mapping

The supplied `HESABU UI system and flow screens.pdf` is the visual reference for the shared Flutter shell.

- Desktop: glass navigation rail with Overview, Workspaces, Reports, and Settings; Android keeps the compact bottom navigation.
- Dashboard: responsive KPI cards, cash-in/out donut, monthly comparison bars, revenue/balance trend, and existing tool cards.
- Workspaces and sessions: local-only selectors remain backed by the encrypted store.
- Analysis screens: existing financial statement, customer, stock, sales, expense, P&L, debt, import, and report routes remain unchanged behind the shared shell.
- States: existing dialogs and error/empty states remain functional and use the shared glass surfaces.

The background atmosphere, glass panels, and shader-backed refraction are shared widgets; no business data is used by the visual layer.
