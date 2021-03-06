//  Created by Cihat Gündüz on 05.05.16.

// swiftlint:disable function_parameter_count

import Foundation

public enum CommandLineAction {
    case interfaces
    case code
    case translate
}

public class CommandLineActor {
    public init() {}

    // MARK: - Instance Methods
    public func act(commonOptions: CommandLineParser.CommonOptions, subCommandOptions: CommandLineParser.SubCommandOptions) {
        guard let path = commonOptions.path.value else { print("Path option `-p` is missing.", level: .error); exit(EX_USAGE) }

        let override = commonOptions.override.value
        let verbose = commonOptions.verbose.value

        switch subCommandOptions {
        case let .codeOptions(localizableOption, defaultToKeysOption, additiveOption, overrideComments, useExtractLocStrings, sortByKeys, unstripped, customFunction, customLocalizableName): // swiftlint:disable:this line_length
            guard let localizable = localizableOption.value else { print("Localizable option `-l` is missing.", level: .error); exit(EX_USAGE) }

            self.actOnCode(
                path: path,
                override: override,
                verbose: verbose,
                localizable: localizable,
                defaultToKeys: defaultToKeysOption.value,
                additive: additiveOption.value,
                overrideComments: overrideComments.value,
                useExtractLocStrings: useExtractLocStrings.value,
                sortByKeys: sortByKeys.value,
                unstripped: unstripped.value,
                customFunction: customFunction.value,
                customLocalizableName: customLocalizableName.value
            )

        case let .interfacesOptions(defaultToBaseOption, unstripped, ignoreEmptyStrings):
            self.actOnInterfaces(
                path: path,
                override: override,
                verbose: verbose,
                defaultToBase: defaultToBaseOption.value,
                unstripped: unstripped.value,
                ignoreEmptyStrings: ignoreEmptyStrings.value
            )

        case let .translateOptions(idOption, secretOption, localeOption):
            guard let id = idOption.value else {
                print("Microsoft Translator API credential 'id' missing. Specify via option `-i`.", level: .error); exit(EX_USAGE)
            }

            guard let secret = secretOption.value else {
                print("Microsoft Translator API credential 'secret' missing. Specify via option `-s`.", level: .error); exit(EX_USAGE)
            }

            guard let locale = localeOption.value else { print("Locale option `-l` is missing.", level: .error); exit(EX_USAGE) }

            self.actOnTranslate(path: path, override: override, verbose: verbose, id: id, secret: secret, locale: locale)

        case let .normalizeOptions(locale, preventDuplicateKeys, sortByKeys, warnEmptyValues, harmonizeWithSource):
            guard let locale = locale.value else { print("Locale option `-l` is missing.", level: .error); exit(EX_USAGE) }

            self.actOnNormalize(
                path: path,
                override: override,
                verbose: verbose,
                locale: locale,
                preventDuplicateKeys: preventDuplicateKeys.value,
                sortByKeys: sortByKeys.value,
                warnEmptyValues: warnEmptyValues.value,
                harmonizeWithSource: harmonizeWithSource.value
            )

        case let .lintOptions(emptyValues, duplicateKeys):
            self.actOnLint(path: path, duplicateKeys: duplicateKeys.value, emptyValues: emptyValues.value)
        }
    }

    private func actOnCode(
        path: String,
        override: Bool,
        verbose: Bool,
        localizable: String,
        defaultToKeys: Bool,
        additive: Bool,
        overrideComments: Bool,
        useExtractLocStrings: Bool,
        sortByKeys: Bool,
        unstripped: Bool,
        customFunction: String?,
        customLocalizableName: String?
    ) {
        let localizableFileName = customLocalizableName ??  "Localizable"
        let allLocalizableStringsFilePaths = StringsFilesSearch.shared.findAllStringsFiles(within: localizable, withFileName: localizableFileName)

        guard !allLocalizableStringsFilePaths.isEmpty else {
            print("No `\(localizableFileName).strings` file found for output.\nTo fix this, please add a `\(localizableFileName).strings` file to your project and click the localize button for the file in Xcode. Alternatively remove the line beginning with `bartycrouch code` in your build script to remove this feature entirely if you don't need it.\nSee https://github.com/Flinesoft/BartyCrouch/issues/11 for further information.", level: .error) // swiftlint:disable:this line_length
            exit(EX_USAGE)
        }

        for localizableStringsFilePath in allLocalizableStringsFilePaths {
            guard FileManager.default.fileExists(atPath: localizableStringsFilePath) else {
                print("No file exists at output path '\(localizableStringsFilePath)'", level: .error); exit(EX_NOINPUT)
            }
        }

        self.incrementalCodeUpdate(
            inputDirectoryPath: path,
            allLocalizableStringsFilePaths,
            override: override,
            verbose: verbose,
            defaultToKeys: defaultToKeys,
            additive: additive,
            overrideComments: overrideComments,
            useExtractLocStrings: useExtractLocStrings,
            sortByKeys: sortByKeys,
            unstripped: unstripped,
            customFunction: customFunction,
            localizableFileName: localizableFileName
        )
    }

    private func actOnInterfaces(path: String, override: Bool, verbose: Bool, defaultToBase: Bool, unstripped: Bool, ignoreEmptyStrings: Bool) {
        let inputFilePaths = StringsFilesSearch.shared.findAllIBFiles(within: path, withLocale: "Base")

        guard !inputFilePaths.isEmpty else { print("No input files found.", level: .warning); exit(EX_OK) }

        for inputFilePath in inputFilePaths {
            guard FileManager.default.fileExists(atPath: inputFilePath) else {
                print("No file exists at input path '\(inputFilePath)'", level: .error); exit(EX_NOINPUT)
            }

            let outputStringsFilePaths = StringsFilesSearch.shared.findAllLocalesForStringsFile(sourceFilePath: inputFilePath).filter { $0 != inputFilePath }

            for outputStringsFilePath in outputStringsFilePaths {
                guard FileManager.default.fileExists(atPath: outputStringsFilePath) else {
                    print("No file exists at output path '\(outputStringsFilePath)'.", level: .error); exit(EX_CONFIG)
                }
            }

            self.incrementalInterfacesUpdate(
                inputFilePath,
                outputStringsFilePaths,
                override: override,
                verbose: verbose,
                defaultToBase: defaultToBase,
                unstripped: unstripped,
                ignoreEmptyStrings: ignoreEmptyStrings
            )
        }
    }

    private func actOnTranslate(path: String, override: Bool, verbose: Bool, id: String, secret: String, locale: String) {
        let inputFilePaths = StringsFilesSearch.shared.findAllStringsFiles(within: path, withLocale: locale)

        guard !inputFilePaths.isEmpty else { print("No input files found.", level: .warning); exit(EX_OK) }

        for inputFilePath in inputFilePaths {
            guard FileManager.default.fileExists(atPath: inputFilePath) else {
                print("No file exists at input path '\(inputFilePath)'.", level: .error); exit(EX_NOINPUT)
            }

            let outputStringsFilePaths = StringsFilesSearch.shared.findAllLocalesForStringsFile(sourceFilePath: inputFilePath).filter { $0 != inputFilePath }

            for outputStringsFilePath in outputStringsFilePaths {
                guard FileManager.default.fileExists(atPath: outputStringsFilePath) else {
                    print("No file exists at output path '\(outputStringsFilePath)'.", level: .error); exit(EX_CONFIG)
                }
            }

            self.translate(id: id, secret: secret, inputFilePath, outputStringsFilePaths, override: override, verbose: verbose)
        }
    }

    private func actOnNormalize(
        path: String,
        override: Bool,
        verbose: Bool,
        locale: String,
        preventDuplicateKeys: Bool,
        sortByKeys: Bool,
        warnEmptyValues: Bool,
        harmonizeWithSource: Bool
    ) {
        let sourceFilePaths = StringsFilesSearch.shared.findAllStringsFiles(within: path, withLocale: locale)
        guard !sourceFilePaths.isEmpty else { print("No source language files found.", level: .warning); exit(EX_OK) }

        for sourceFilePath in sourceFilePaths {
            guard FileManager.default.fileExists(atPath: sourceFilePath) else {
                print("No file exists at input path '\(sourceFilePath)'.", level: .error); exit(EX_NOINPUT)
            }

            let allStringsFilePaths = StringsFilesSearch.shared.findAllLocalesForStringsFile(sourceFilePath: sourceFilePath)
            let targetStringsFilePaths = allStringsFilePaths.filter { $0 != sourceFilePath }

            for targetStringsFilePath in targetStringsFilePaths {
                guard FileManager.default.fileExists(atPath: targetStringsFilePath) else {
                    print("No file exists at other language path '\(targetStringsFilePath)'.", level: .error); exit(EX_CONFIG)
                }
            }

            targetStringsFilePaths.forEach { filePath in
                let stringsFileUpdater = StringsFileUpdater(path: filePath)
                do {
                    try stringsFileUpdater?.harmonizeKeys(withSource: sourceFilePath)
                } catch {
                    print("Could not harmonize keys with source file at path \(sourceFilePath).", level: .error); exit(EX_USAGE)
                }
            }

            allStringsFilePaths.forEach { filePath in
                let stringsFileUpdater = StringsFileUpdater(path: filePath)

                if preventDuplicateKeys {
                    stringsFileUpdater?.preventDuplicateEntries()
                }

                if sortByKeys {
                    stringsFileUpdater?.sortByKeys()
                }

                if warnEmptyValues {
                    stringsFileUpdater?.warnEmptyValueEntries()
                }
            }
        }
    }

    private func actOnLint(path: String, duplicateKeys: Bool, emptyValues: Bool) {
        let stringsFilePaths = StringsFilesSearch.shared.findAllStringsFiles(within: path)
        guard !stringsFilePaths.isEmpty else { print("No Strings files found.", level: .warning); exit(EX_OK) }

        let totalChecks: Int = [duplicateKeys, emptyValues].filter { $0 }.count

        if totalChecks <= 0 {
            print("No checks specified. Run `bartycrouch lint` to see all available linting options.", level: .warning)
        }

        var failedFilePaths: [String] = []
        var totalFails = 0

        for stringsFilePath in stringsFilePaths {
            guard FileManager.default.fileExists(atPath: stringsFilePath) else {
                print("No file exists at file path '\(stringsFilePath)'.", level: .error); exit(EX_NOINPUT)
            }

            let stringsFileUpdater = StringsFileUpdater(path: stringsFilePath)
            var lintingFailed = false

            if duplicateKeys {
                let duplicateKeyEntries: [String: [StringsFileUpdater.TranslationEntry]] = stringsFileUpdater!.findDuplicateEntries()
                for (duplicateKey, translations) in duplicateKeyEntries {
                    print("Found \(translations.count) translations for key '\(duplicateKey)' in file \(stringsFilePath).", level: .info)
                }

                if !duplicateKeyEntries.isEmpty {
                    lintingFailed = true
                    totalFails += duplicateKeyEntries.count
                }
            }

            if emptyValues {
                let emptyValueEntries: [StringsFileUpdater.TranslationEntry] = stringsFileUpdater!.findEmptyValueEntries()
                for translation in emptyValueEntries {
                    print("Found empty value for key '\(translation.key)' in file \(stringsFilePath).", level: .info)
                }

                if !emptyValueEntries.isEmpty {
                    lintingFailed = true
                    totalFails += emptyValueEntries.count
                }
            }

            if lintingFailed {
                failedFilePaths.append(stringsFilePath)
            }
        }

        if !failedFilePaths.isEmpty {
            // swiftlint:disable:next line_length
            print("\(totalFails) issue(s) found in \(failedFilePaths.count) file(s). Executed \(totalChecks) checks in \(stringsFilePaths.count) Strings file(s) in total.", level: .error)
            exit(EXIT_FAILURE)
        } else {
            print("\(totalChecks) check(s) passed for \(stringsFilePaths.count) Strings file(s).", level: .success)
            exit(EX_OK)
        }
    }

    private func incrementalCodeUpdate(
        inputDirectoryPath: String,
        _ outputStringsFilePaths: [String],
        override: Bool,
        verbose: Bool,
        defaultToKeys: Bool,
        additive: Bool,
        overrideComments: Bool,
        useExtractLocStrings: Bool,
        sortByKeys: Bool,
        unstripped: Bool,
        customFunction: String?,
        localizableFileName: String
    ) {
        let extractedStringsFileDirectory = inputDirectoryPath + "/tmpstrings/"

        do {
            try FileManager.default.createDirectory(atPath: extractedStringsFileDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error.localizedDescription, level: .error)
            exit(EX_IOERR)
        }

        let codeCommander: CodeCommander = useExtractLocStrings ? ExtractLocStringsCommander.shared : GenStringsCommander.shared

        guard codeCommander.export(
            stringsFilesToPath: extractedStringsFileDirectory, fromCodeInDirectoryPath: inputDirectoryPath, customFunction: customFunction
        ) else {
            print("Could not extract strings from Code in directory '\(inputDirectoryPath)'.", level: .error)
            exit(EX_UNAVAILABLE)
        }

        let extractedLocalizableStringsFilePath = extractedStringsFileDirectory + "Localizable.strings"
        guard FileManager.default.fileExists(atPath: extractedLocalizableStringsFilePath) else {
            print("No localizations extracted from Code in directory '\(inputDirectoryPath)'.", level: .warning)

            if sortByKeys {
                // sort file even if no localizations extracted if specified to do so
                for outputStringsFilePath in outputStringsFilePaths {
                    guard let stringsFileUpdater = StringsFileUpdater(path: outputStringsFilePath) else {
                        print("Could not read strings file at path '\(outputStringsFilePath)'", level: .error)
                        exit(EX_CONFIG)
                    }

                    stringsFileUpdater.sortByKeys(keepWhitespaceSurroundings: unstripped)
                    if verbose { print("Sorted keys of file '\(outputStringsFilePath)'.", level: .info) }
                }
            }

            exit(EX_OK) // NOTE: Expecting to see this only for empty project situations.
        }

        for outputStringsFilePath in outputStringsFilePaths {
            guard let stringsFileUpdater = StringsFileUpdater(path: outputStringsFilePath) else {
                print("Could not read strings file at path '\(outputStringsFilePath)'", level: .error)
                exit(EX_CONFIG)
            }

            stringsFileUpdater.incrementallyUpdateKeys(
                withStringsFileAtPath: extractedLocalizableStringsFilePath,
                addNewValuesAsEmpty: !defaultToKeys,
                override: override,
                keepExistingKeys: additive,
                overrideComments: overrideComments,
                sortByKeys: sortByKeys,
                keepWhitespaceSurroundings: unstripped
            )

            if verbose { print("Incrementally updated keys of file '\(outputStringsFilePath)'.", level: .info) }
        }

        do {
            try FileManager.default.removeItem(atPath: extractedStringsFileDirectory)
        } catch {
            print("Temporary strings files couldn't be deleted at path '\(extractedStringsFileDirectory)'", level: .error)
            exit(EX_IOERR)
        }

        print("BartyCrouch: Successfully updated strings file(s) of Code files.", level: .info)
    }

    private func incrementalInterfacesUpdate(
        _ inputFilePath: String,
        _ outputStringsFilePaths: [String],
        override: Bool,
        verbose: Bool,
        defaultToBase: Bool,
        unstripped: Bool,
        ignoreEmptyStrings: Bool
    ) {
        let extractedStringsFilePath = inputFilePath + ".tmpstrings"

        guard IBToolCommander.shared.export(stringsFileToPath: extractedStringsFilePath, fromIbFileAtPath: inputFilePath) else {
            print("Could not extract strings from Storyboard or XIB at path '\(inputFilePath)'.", level: .error)
            exit(EX_UNAVAILABLE)
        }

        for outputStringsFilePath in outputStringsFilePaths {
            guard let stringsFileUpdater = StringsFileUpdater(path: outputStringsFilePath) else {
                print("Could not read strings file at path '\(outputStringsFilePath)'", level: .error)
                exit(EX_CONFIG)
            }

            stringsFileUpdater.incrementallyUpdateKeys(
                withStringsFileAtPath: extractedStringsFilePath,
                addNewValuesAsEmpty: !defaultToBase,
                override: override,
                keepWhitespaceSurroundings: unstripped,
                ignoreEmptyStrings: ignoreEmptyStrings
            )

            if verbose {
                print("Incrementally updated keys of file '\(outputStringsFilePath)'.", level: .info)
            }
        }

        do {
            try FileManager.default.removeItem(atPath: extractedStringsFilePath)
        } catch {
            print("Temporary strings file couldn't be deleted at path '\(extractedStringsFilePath)'", level: .error)
            exit(EX_IOERR)
        }

        print("BartyCrouch: Successfully updated strings file(s) of Storyboard or XIB file.", level: .info)
    }

    private func translate(id: String, secret: String, _ inputFilePath: String, _ outputStringsFilePaths: [String], override: Bool, verbose: Bool) {
        var overallTranslatedValuesCount = 0
        var filesWithTranslatedValuesCount = 0

        for outputStringsFilePath in outputStringsFilePaths {
            guard let stringsFileUpdater = StringsFileUpdater(path: outputStringsFilePath) else {
                print("Could not read strings file at path '\(outputStringsFilePath)'", level: .error)
                exit(EX_CONFIG)
            }

            let translationsCount = stringsFileUpdater.translateEmptyValues(
                usingValuesFromStringsFile: inputFilePath, clientId: id, clientSecret: secret, override: override
            )

            if verbose { print("Translated file '\(outputStringsFilePath)' with \(translationsCount) changes.", level: .info) }

            if translationsCount > 0 {
                overallTranslatedValuesCount += translationsCount
                filesWithTranslatedValuesCount += 1
            }
        }

        print("BartyCrouch: Successfully translated \(overallTranslatedValuesCount) values in \(filesWithTranslatedValuesCount) files.", level: .info)
    }
}
