#!/usr/bin/swift

import Foundation
import SwiftCLI
import TezosGenFramework

let generatorCLI = CLI(singleCommand: GenerateCommand())

generatorCLI.goAndExit()
