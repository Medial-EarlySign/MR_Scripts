import csvAnalyzer, xmlAnalyzer

class Configuration:
    def __init__(self):
        self.schema_name = 'MACCABI_RAW'
        self.tableName = 'Hospitalization'
        self.dataDir = 'C:\\Users\\Alon\\Documents\\RawData\\Maccabi'
        self.filesFormatFunc = lambda f : f.endswith('Hospitalization.txt')

        encodeFunc = lambda st : st.decode('windows-1255')
        manipulateVal = dict()
        manipulateVal['care_giver_desc'] = encodeFunc
        manipulateVal['care_giver_dprt_desc'] = encodeFunc
        self.dataAnalyzerFun = lambda f:  csvAnalyzer.analyzeFile(f, delimiter = ',', manipulationFunc = manipulateVal , additionalConstFields = None)
        
