import sqlite3

con = sqlite3.connect('/root/.homeassistant/home-assistant_v2.db')
cur = con.cursor()
rows = cur.execute("""
    SELECT sm.entity_id, s.state, s.last_updated_ts 
    FROM states_meta sm 
    JOIN states s ON sm.metadata_id = s.metadata_id 
    WHERE sm.entity_id LIKE '%tablet%'
    ORDER BY s.state_id DESC
    LIMIT 10
""").fetchall()

for row in rows:
    print(row)
