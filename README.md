# tezosgen

[![CI Status](http://img.shields.io/travis/AckeeCZ/tezosgen.svg?style=flat)](https://travis-ci.org/AckeeCZ/tezosgen)
[![Version](https://img.shields.io/cocoapods/v/TezosGen.svg?style=flat)](http://cocoapods.org/pods/TezosGen)
[![License](https://img.shields.io/cocoapods/l/TezosGen.svg?style=flat)](http://cocoapods.org/pods/TezosGen)
[![Swift Package Manager compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/cocoapods/p/TezosGen.svg?style=flat)](http://cocoapods.org/pods/TezosGen)

## Installation

There are multiple possibilities to install TezosGen on your machine or in your project, depending on your preferences and needs. Note that if you do not install `TezosGen` using `Cocoapods`, you will have have to import `TezosSwift` by yourself.

<details>
<summary><strong>Download the ZIP</strong> for the latest release</summary>

* [Go to the GitHub page for the latest release](https://github.com/AckeeCZ/Tezos-iOS-Dev-Kit/releases/latest)
* Download the `TezosGen-x.y.z.zip` file associated with that release
* Extract the content of the zip archive in your project directory

We recommend that you **unarchive the ZIP inside your project directory** and **commit its content** to git. This way, **all coworkers will use the same version of TezosGen for this project**.

If you unarchived the ZIP file in a folder e.g. called `TezosGen`, you can then invoke it like this:

```sh
TezosGen/bin/tezosgen …
```

---
</details>
<details>
<summary>Via <strong>CocoaPods</strong></summary>

If you're using CocoaPods, you can simply add `pod 'TezosGen'` to your `Podfile`.

This will download the `TezosGen` binaries and dependencies in `Pods/` during your next `pod install` execution.

Given that you can specify an exact version for ``TezosGen`` in your `Podfile`, this allows you to ensure **all coworkers will use the same version of TezosGen for this project**.

You can then invoke TezosGen from your terminal:
```sh
Pods/TezosGen/TezosGen …
```

_Note: TezosGen isn't really a pod, as it's not a library your code will depend on at runtime; so the installation via CocoaPods is just a trick that installs the TezosGen binaries in the Pods/ folder, but you won't see any swift files in the Pods/TezosGen group in your Xcode's Pods.xcodeproj. That's normal: the TezosGen binary is still present in that folder in the Finder._

---
</details>
<details>
<summary><strong>System-wide installation</strong></summary>

* [Go to the GitHub page for the latest release](https://github.com/AckeeCZ/Tezos-iOS-Dev-Kit/releases/latest)
* Download the `TezosGen-x.y.z.zip` file associated with that release
* Extract the content of the zip archive

1. `cd` into the unarchived directory 
2. `make install`
3. You then invoke tezosgen simply with `tezosgen ...`

</details>

### iOS MVVM Project Template

We have also created iOS MVVM Project Template, so setting your project has never been easier. 
Easily follow the [installation instructions](https://github.com/AckeeCZ/iOS-MVVM-ProjectTemplate).
After you are done, add `name_of_your_abi.json` file to `Resources`. Then add `TezosGen` to your `Podfile`, do `pod install` and run this command in your project root directory:
```sh
Pods/TezosGen/TezosGen HelloContract NameOfYourProject/Resources/abi.json -x NameOfYourProject.xcodeproj -o NameOfYourProject/Model/Generated/GeneraredContracts
```

## Usage

### Example

You can find an example app [here](https://github.com/AckeeCZ/TezosSwift).

### How to Get Contract Specifcation

To be able to generate smart contract code, we first need to have its specification. To find it, simply run `curl https://url_to_your_node/chains/main/blocks/head/context/contracts/contract_address | tr -d '\n'`.

The output could look something like this:

```{"manager":"tz1dD918PXDuUHV6Mh6z2QqMukA67YULuhqd","balance":"21000000","spendable":false,"delegate":{"setable":false},"script":{"code":[{"prim":"parameter","args":[{"prim":"set","args":[{"prim":"nat"}]}]},{"prim":"storage","args":[{"prim":"set","args":[{"prim":"nat"}]}]},{"prim":"code","args":[[{"prim":"CDR"},{"prim":"NIL","args":[{"prim":"operation"}]},{"prim":"PAIR"}]]}],"storage":[{"int":"1"},{"int":"2"},{"int":"3"}]},"counter":"0"}```

What we need for our generator is hidden under the `code` key and we need to obtain the parameter and storage. So the specification for this contract, after a little modification, would look like this: 

```{"parameter": {"prim":"set","args":[{"prim":"nat"}]}, "storage": {"prim":"set","args":[{"prim":"nat"}]}}```

To expand on this, the specification should look like this:

```{"parameter": {code_specified_under_args_for_parameter}, "storage": {code_specified_under_args_for_parameter}```

By defaul the parameters are then indexed from number one for better readability, but you can also name your parameters! (and if the values are named in the contract itself, you will get this for free). To do this, it would look like this: 
```{"parameter": {"prim":"set", "annots":["%first"],"args":[{"prim":"nat"}]}, "storage": {"prim":"set","args":[{"prim":"nat"}]}}```

(that is add to the type a new key-value pair `"annots":["%desired_name"]`)

### Codegen
The standard usage looks like this `tezosgen HelloContract path_to_abi/abi.json -x path_to_xcodeproj/project.xcodeproj -o relative_output_path`

Please <strong>note</strong> that the output path option (`--output`) should be relative to your project - if your generated files are in `YourProjectName/MainFolder/GeneratedContracts` folder, then you should write `--output MainFolder/GeneratedContracts`
For your projects to be bound you also <strong>must</strong> set the `--xcode` option as well. Otherwise you will have to drag the files to your projects manually.

### Usage of Generated Codes

The standard call using code created by `codegen` looks like this:
```swift
import TezosSwift
tezosClient.optionalStringContract(at: "KT1Rh4iEMxBLJbDbz7iAB6FGLJ3mSCx3qFrW").call(param1: "hello").send(from: wallet, amount: Tez(1), completion: { result in
    switch result {
    case .failure(let error):
        XCTFail("Failed with error: \(error)")
        testCompletionExpectation.fulfill()
    case .success(_):
        testCompletionExpectation.fulfill()
    }
})
``` 

`wallet` and `tezosClient` should be created with [TezosSwift](https://github.com/AckeeCZ/TezosSwift)
Also note that right now the created code works with `ReactiveSwift` only.

Result of the call is either a `String` hash of the transaction or an `TezosError`.
