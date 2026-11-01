# Boots a Tart VM into Recovery and turns SIP off, so scripts/test-vm can grant
# Accessibility by writing TCC.db. From cirruslabs/macos-image-templates
# (templates/disable-sip.pkr.hcl at d6a3774, MIT licence). Changed: the disk size
# of the image; recovery_partition "keep", without which the plugin removed the
# recovery partition; and 120 s instead of 10 s for Recovery to come up, which on
# macOS 27.2 took about 100 s after "Options". csrutil there asks for y and the
# password of admin, the only user. It needs a US keyboard, set by setup.
packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_name" {
  type = string
}

source "tart-cli" "tart" {
  vm_name      = "${var.vm_name}"
  recovery     = true
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 60
  communicator = "none"
  recovery_partition = "keep"
  boot_command = [
    # Skip over "Macintosh" and select "Options"
    # to boot into macOS Recovery
    "<wait60s><right><right><enter>",
    # Open Terminal
    "<wait120s><leftAltOn>T<leftAltOff>",
    # Disable SIP
    "<wait10s>csrutil disable<enter>",
    "<wait10s>y<enter>",
    "<wait10s>admin<enter>",
    # Shutdown
    "<wait10s>halt<enter>"
  ]
}

build {
  sources = ["source.tart-cli.tart"]
}
