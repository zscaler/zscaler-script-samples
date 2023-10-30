# loading in modules
import sqlite3
import time

# creating file path
dbfile = 'C:/ProgramData/Zscaler/upm_device_stats.db'
# Create a SQL connection to our SQLite database

while True:
    try:
        # Signal Quality 33
        time.sleep(15)
        print("Executing again ..")
        con = sqlite3.connect(dbfile)
        cur = con.cursor()
        update_signal_quality = [a for a in cur.execute(
            "UPDATE main.tbl_wifi_info SET signal_quality = '33' WHERE ssid = '3Com_Wifi'")]
        update_rssi_dbm = [a for a in
                           cur.execute("UPDATE main.tbl_wifi_info SET rssi_dbm = '-33' WHERE ssid = '3Com_Wifi'")]
        table_list = [a for a in cur.execute("SELECT signal_quality, rssi_dbm FROM \"main\".\"tbl_wifi_info\"")];
        con.commit()
        con.close()
        # Signal Quality 42
        time.sleep(15)
        print("Executing again ..")
        con = sqlite3.connect(dbfile)
        cur = con.cursor()
        update_signal_quality = [a for a in cur.execute(
            "UPDATE main.tbl_wifi_info SET signal_quality = '42' WHERE ssid = '3Com_Wifi'")]
        update_rssi_dbm = [a for a in
                           cur.execute("UPDATE main.tbl_wifi_info SET rssi_dbm = '-42' WHERE ssid = '3Com_Wifi'")]
        table_list = [a for a in cur.execute("SELECT signal_quality, rssi_dbm FROM \"main\".\"tbl_wifi_info\"")];
        con.commit()
        con.close()
        # Signal Quality 15
        time.sleep(15)
        print("Executing again ..")
        con = sqlite3.connect(dbfile)
        cur = con.cursor()
        update_signal_quality = [a for a in cur.execute(
            "UPDATE main.tbl_wifi_info SET signal_quality = '15' WHERE ssid = '3Com_Wifi'")]
        update_rssi_dbm = [a for a in
                           cur.execute("UPDATE main.tbl_wifi_info SET rssi_dbm = '-15' WHERE ssid = '3Com_Wifi'")]
        table_list = [a for a in cur.execute("SELECT signal_quality, rssi_dbm FROM \"main\".\"tbl_wifi_info\"")];
        con.commit()
        con.close()
        # Signal Quality 24
        time.sleep(15)
        print("Executing again ..")
        con = sqlite3.connect(dbfile)
        cur = con.cursor()
        update_signal_quality = [a for a in cur.execute(
            "UPDATE main.tbl_wifi_info SET signal_quality = '24' WHERE ssid = '3Com_Wifi'")]
        update_rssi_dbm = [a for a in
                           cur.execute("UPDATE main.tbl_wifi_info SET rssi_dbm = '-24' WHERE ssid = '3Com_Wifi'")]
        table_list = [a for a in cur.execute("SELECT signal_quality, rssi_dbm FROM \"main\".\"tbl_wifi_info\"")];
        con.commit()
        con.close()
        # Signal Quality 51
        time.sleep(15)
        print("Executing again ..")
        con = sqlite3.connect(dbfile)
        cur = con.cursor()
        update_signal_quality = [a for a in cur.execute(
            "UPDATE main.tbl_wifi_info SET signal_quality = '51' WHERE ssid = '3Com_Wifi'")]
        update_rssi_dbm = [a for a in
                           cur.execute("UPDATE main.tbl_wifi_info SET rssi_dbm = '-51' WHERE ssid = '3Com_Wifi'")]
        table_list = [a for a in cur.execute("SELECT signal_quality, rssi_dbm FROM \"main\".\"tbl_wifi_info\"")];
        con.commit()
        con.close()
    except:
        print("Executing again ..")
