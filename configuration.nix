{ config, pkgs, lib, ... }:
{

	imports = [ secrets/networking.nix ];

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

	boot.loader = {
		raspberryPi = {
			enable = true;
			version = 3;
			uboot.enable = true;
		};
		grub.enable = false;
		generic-extlinux-compatible.enable = true;
	};

	time.timeZone = "Asia/Kolkata";

	security.sudo.wheelNeedsPassword = false;

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

	services = {
		openssh.enable = true;
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
				in plugins: with plugins; [ themeify stlviewer ender3v2tempfix ender3v2tempfix ];
		};
		klipper = {
			enable = true;
			octoprintIntegration = true;
		};
	};

	fileSystems."/" = {
		device = "/dev/disk/by-label/NIXOS_SD";
		fsType = "ext4";
	};

	hardware.enableRedistributableFirmware = true;
	hardware.firmware = [ pkgs.wireless-regdb ];

	# Pi 3 has very little RAM, needs swap for nixos-rebuild
	swapDevices = [
		{
			device = "/swapfile";
			size = 1024;
		}
	];

	environment = {
		systemPackages = with pkgs; [
			htop tmux
		];
	};

	networking = {
		hostName = "ender";
		# TODO: add to module
		firewall.allowedTCPPorts = [ 5000 ];
	};
}
