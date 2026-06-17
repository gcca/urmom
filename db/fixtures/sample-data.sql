PRAGMA foreign_keys = ON;

BEGIN;

INSERT OR IGNORE INTO auth_user (username, password, email, is_active, created_at) VALUES
  ('jill.valentine', 'fixture-password', 'jill.valentine@example.test', 1, 1783209600),
  ('chris.redfield', 'fixture-password', 'chris.redfield@example.test', 1, 1783209600),
  ('barry.burton', 'fixture-password', 'barry.burton@example.test', 1, 1783209600),
  ('rebecca.chambers', 'fixture-password', 'rebecca.chambers@example.test', 1, 1783209600),
  ('albert.wesker', 'fixture-password', 'albert.wesker@example.test', 1, 1783209600),
  ('brad.vickers', 'fixture-password', 'brad.vickers@example.test', 1, 1783209600),
  ('richard.aiken', 'fixture-password', 'richard.aiken@example.test', 1, 1783209600),
  ('forest.speyer', 'fixture-password', 'forest.speyer@example.test', 1, 1783209600),
  ('kenneth.sullivan', 'fixture-password', 'kenneth.sullivan@example.test', 1, 1783209600),
  ('joseph.frost', 'fixture-password', 'joseph.frost@example.test', 1, 1783209600);

INSERT OR IGNORE INTO dash_app (appname, description) VALUES
  ('ticketeer', 'Ticket intake and resolution tracking'),
  ('u-board', 'Team board for planning and status'),
  ('checkmate', 'Checklist and verification workflows'),
  ('machin8', 'Automation control surface'),
  ('overlord', 'Operations command dashboard'),
  ('dailysales-neo', 'Daily sales reporting dashboard');

INSERT OR IGNORE INTO dash_binding (username, appname) VALUES
  ('jill.valentine', 'ticketeer'),
  ('jill.valentine', 'u-board'),
  ('jill.valentine', 'checkmate'),
  ('jill.valentine', 'machin8'),
  ('jill.valentine', 'overlord'),
  ('jill.valentine', 'dailysales-neo'),
  ('chris.redfield', 'ticketeer'),
  ('chris.redfield', 'u-board'),
  ('chris.redfield', 'checkmate'),
  ('chris.redfield', 'overlord'),
  ('barry.burton', 'ticketeer'),
  ('barry.burton', 'machin8'),
  ('barry.burton', 'overlord'),
  ('rebecca.chambers', 'u-board'),
  ('rebecca.chambers', 'checkmate'),
  ('rebecca.chambers', 'dailysales-neo'),
  ('albert.wesker', 'overlord'),
  ('albert.wesker', 'machin8'),
  ('albert.wesker', 'dailysales-neo'),
  ('brad.vickers', 'ticketeer'),
  ('richard.aiken', 'u-board'),
  ('richard.aiken', 'checkmate'),
  ('forest.speyer', 'machin8'),
  ('kenneth.sullivan', 'dailysales-neo'),
  ('joseph.frost', 'ticketeer');

COMMIT;
