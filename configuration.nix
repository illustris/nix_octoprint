{ config, pkgs, lib, ... }:
{

	imports = [ secrets/networking.nix ];

	boot = {
		# make the camera available as v4l device
		kernelModules = [ "bcm2835-v4l2" ];
		extraModprobeConfig = ''
			options uvcvideo nodrop=1 timeout=6000
		'';
		loader = {
			raspberryPi = {
				enable = true;
				version = 3;
				uboot.enable = true;
			};
			grub.enable = false;
			generic-extlinux-compatible.enable = true;
		};
	};

	environment = {
		etc.nixpkgs.source = (import ./nix/sources.nix).nixpkgs;
		systemPackages = with pkgs; [
			htop
			tmux
		];
	};

	fileSystems."/" = {
		device = "/dev/disk/by-label/NIXOS_SD";
		fsType = "ext4";
	};

	hardware.enableRedistributableFirmware = true;
	hardware.firmware = [ pkgs.wireless-regdb ];

	networking = {
		hostName = "ender";
		# TODO: add to module
		firewall.allowedTCPPorts = [ 80 ];
	};

	nixpkgs.overlays = [
		(self: super: {
			# https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_3
			# "In case wlan0 is missing, try overlaying an older firmwareLinuxNonfree confirmed to be working"
			firmwareLinuxNonfree = super.firmwareLinuxNonfree.overrideAttrs (old: {
				version = "2020-12-18";
				src = pkgs.fetchgit {
					url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git";
					rev = "b79d2396bc630bfd9b4058459d3e82d7c3428599";
					sha256 = "1rb5b3fzxk5bi6kfqp76q1qszivi0v1kdz1cwj2llp5sd9ns03b5";
				};
				outputHash = "1p7vn2hfwca6w69jhw5zq70w44ji8mdnibm1z959aalax6ndy146";
			});
		})
	];

	# TODO: pin nixpkgs with niv
	#programs.bash.shellAliases = {
	#	nt = "nix-shell /etc/nixos/shell.nix --run \"sudo nixos-rebuild test\"";
	#	ns = "nix-shell /etc/nixos/shell.nix --run \"sudo nixos-rebuild switch\"";
	#};

	services = {
		klipper = {
			enable = true;
			octoprintIntegration = true;
		};
		# expose webcanm and octoprint on 80
		haproxy = {
			enable = true;
			config = ''global
        maxconn 4096
        user haproxy
        group haproxy
        daemon
        log 127.0.0.1 local0 debug

defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        retries 3
        option redispatch
        option http-server-close
        option forwardfor
        maxconn 2000
        timeout connect 5s
        timeout client  15m
        timeout server  15m

frontend public
        bind *:80
        use_backend webcam if { path_beg /webcam/ }
        default_backend octoprint

backend octoprint
        option forwardfor
        server octoprint1 127.0.0.1:5000

backend webcam
	http-request replace-path /webcam/(.*) /\1
        server webcam1  127.0.0.1:5050
'';
		};
		# expose webcam over HTTP, listens on port 5050
		mjpg-streamer = {
			enable = true;
			inputPlugin = "input_uvc.so";
		};
		octoprint = {
			enable = true;
			plugins = let
				# https://plugins.octoprint.org/plugins/ender3v2tempfix/
				# TODO: add to nixpkgs
				ender3v2tempfix = pkgs.python3Packages.buildPythonPackage {
					pname = "OctoPrintPlugin-ender3v2tempfix";
					propagatedBuildInputs = [pkgs.octoprint];
					doCheck = false;
					version = "unstable-2019-04-27";
					src = pkgs.fetchFromGitHub {
						owner = "SimplyPrint";
						repo = "OctoPrint-Creality2xTemperatureReportingFix";
						rev = "2c4183b6a0242a24ebf646d7ac717cd7a2db2bcf";
						sha256 = "03bc2zbffw4ksk8if90kxhs3179nbhb4xikp4f0adm3lrnvxkd3s";
					};
				};
				in plugins: with plugins; [
					ender3v2tempfix
					themeify
					stlviewer
					#abl-expert
					#bedlevelvisualizer
					#costestimation
					#gcodeeditor
					telegram
					touchui
					#octoklipper
					octoprint-dashboard
				 ];
		};
		openssh.enable = true;
	};

	security.sudo.wheelNeedsPassword = false;

	# Pi 3 has very little RAM, needs swap for nixos-rebuild
	swapDevices = [
		{
			device = "/swapfile";
			size = 1024;
		}
	];

	time.timeZone = "Asia/Kolkata";

	users.users = {
		illustris = {
			isNormalUser = true;
			extraGroups = [ "wheel" ];
			openssh.authorizedKeys.keyFiles = [ ./secrets/ssh_pubkeys ];
		};
		root.openssh.authorizedKeys.keyFiles = [ ./secrets/ssh_pubkeys ];
		# TODO: add to octoprint module
		octoprint.extraGroups = [ "dialout" ];
	};

}
