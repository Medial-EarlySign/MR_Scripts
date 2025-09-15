import csvAnalyzer, xmlAnalyzer, medialAnalyzer, re

class Configuration:
    def __init__(self):
        self.schema_name = 'MACCABI_CFG'
        self.tableName = 'Dictionaries'
        self.dataDir = 'W:\\CancerData\\Repositories\\Mode3\\Maccabi_feb2016'
        regFiles= re.compile('.*dict\..*', re.IGNORECASE)
        self.filesFormatFunc = lambda f : len(regFiles.findall(f)) > 0

        encodeFunc = lambda st : st.decode('windows-1255')
        manipulateVal = dict()
        #manipulateVal['description'] = encodeFunc
        self.upload_bulk_size = 1000
        self.dataAnalyzerFunLazy = lambda f, h:  medialAnalyzer.analyzeMedialFile(f, delimiter = '\t',
                                                                             manipulationFunc = manipulateVal , additionalConstFields =  {'file_path' : f})
