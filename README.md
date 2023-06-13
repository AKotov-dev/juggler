# Juggler
**Dependencies:** fping gtk2 procps-ng luntikwg  
Packages for linking: luntik, protonvpn, openvpngui  
The main switch script is in: `/etc/juggler/juggler.sh`  
  
The `Juggler` allows you to connect to vpn2 via vpn1 and vice versa, even if vpn2 is blocked. It is important that these are different protocols: WireGuard and OpenVPN. [LuntikWG](https://github.com/AKotov-dev/luntikwg) (mandatory) and [OpenVPN-GUI](https://github.com/AKotov-dev/OpenVPN-GUI), [ProtonVPN-GUI](https://github.com/AKotov-dev/protonvpn-gui) or [Luntik](https://github.com/AKotov-dev/luntik) are used as the main clients/services.  
  
`VPN2 - default gateway` - Different Linux systems use different network tools. If switching from one VPN to another does not occur, installing this checker will allow you to attempt to withdraw the default route for a working VPN1 after connecting a blocked VPN2.

How it works:
--
Upload `*.conf` and `*.ovpn` configurations to `LuntikWG` and to any other client, respectively. Start connecting the first one and stop, then connect the second one and stop. Open `Juggler` and specify the client services that you want to run/monitor and click `Start`. As a result, a connection with vpn2 will be established via vpn1 or vice versa, depending on the selected option (1/2 or 2/1).
  
![](https://github.com/AKotov-dev/juggler/blob/main/ScreenShot5.png)  
  
**Note:** Your individual `systemd` services and interfaces can be used as services and interfaces for monitoring and launching. Don't forget to open the necessary `iptables` ports. The Internet should be free!  
