/*
 *******************************************************************************
 *
 *        filename: main.swift
 *     description: linux virtual machine
 *         created: 2025/08/12
 *          author: ticktechman
 *
 *******************************************************************************
 */

import Foundation
import Virtualization

func logi(_ message: String) {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
  let now = formatter.string(from: Date())
  print("[I|\(now)] \(message)")
}

func loge(_ message: String) {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
  let now = formatter.string(from: Date())
  print("[E|\(now)] \(message)")
}

// Virtual Machine Delegate
class Delegate: NSObject {}
extension Delegate: VZVirtualMachineDelegate {
  func guestDidStop(_ virtualMachine: VZVirtualMachine) {
    logi("The guest shut down. Exiting.")
    exit(EXIT_SUCCESS)
  }
}

// Creates a Linux bootloader with the given kernel and initial ramdisk.
func createBootLoader() -> VZBootLoader {
  let bootLoader = VZLinuxBootLoader(kernelURL: URL(fileURLWithPath: "./oss-img/Image"))
  bootLoader.commandLine = "console=hvc0 root=/dev/vda rw"
  return bootLoader
}

// serial port console for IO
func createConsoleConfiguration() -> VZSerialPortConfiguration {
  let consoleConfiguration = VZVirtioConsoleDeviceSerialPortConfiguration()
  let inputFileHandle = FileHandle.standardInput
  let outputFileHandle = FileHandle.standardOutput
  var attributes = termios()
  tcgetattr(inputFileHandle.fileDescriptor, &attributes)
  attributes.c_iflag &= ~tcflag_t(ICRNL)
  attributes.c_lflag &= ~tcflag_t(ICANON | ECHO)
  tcsetattr(inputFileHandle.fileDescriptor, TCSANOW, &attributes)

  let stdioAttachment = VZFileHandleSerialPortAttachment(
    fileHandleForReading: inputFileHandle,
    fileHandleForWriting: outputFileHandle
  )

  consoleConfiguration.attachment = stdioAttachment
  return consoleConfiguration
}

func createVirtualMachineConf() -> VZVirtualMachineConfiguration {
  let configuration = VZVirtualMachineConfiguration()
  configuration.cpuCount = 2
  configuration.memorySize = 2 * 1024 * 1024 * 1024
  configuration.serialPorts = [createConsoleConfiguration()]
  configuration.bootLoader = createBootLoader()
  do {
    let url = URL(filePath: "./oss-img/root.img")
    let attachment = try VZDiskImageStorageDeviceAttachment(url: url, readOnly: false)
    let device = VZVirtioBlockDeviceConfiguration(attachment: attachment)
    configuration.storageDevices.append(device)

    // configure network
    let networkDevice = VZVirtioNetworkDeviceConfiguration()
    networkDevice.attachment = VZNATNetworkDeviceAttachment()
    configuration.networkDevices = [networkDevice]

    try configuration.validate()
  }
  catch {
    loge("configuration failed: \(error)")
    exit(EXIT_FAILURE)
  }
  return configuration
}

func main() {
  let configuration = createVirtualMachineConf()
  let vm = VZVirtualMachine(configuration: configuration)
  let delegate = Delegate()
  vm.delegate = delegate

  vm.start { (result) in
    if case let .failure(error) = result {
      loge("Failed to start the virtual machine. \(error)")
      exit(EXIT_FAILURE)
    }
  }

  RunLoop.main.run(until: Date.distantFuture)
}

//-----------------------------------
// main
//-----------------------------------
main()

/******************************************************************************/
