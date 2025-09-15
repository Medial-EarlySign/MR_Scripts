import re, sys, os

def splitLine(line, delimiter, supportQ = True):
    currMatch = 0
    escaping = False
    qCnt = False
    bufferStr = ''

    tokens = list()
    for ch in line:
        if ch == '"' and not(escaping):
            qCnt = not(qCnt)
            
        escaping = (ch =='\\')
        
        if ch == delimiter[currMatch] and (not(qCnt) or not(supportQ)):
            currMatch = currMatch + 1
            if currMatch >= len(delimiter):
                currMatch = 0
                tokens.append(bufferStr)
                bufferStr = ''
        else:
            bufferStr = bufferStr + ch

    if len(bufferStr) > 0:
        tokens.append(bufferStr)

    return tokens
            
def analyzeCsv(csvContent, delimiter = ',', supportQ = True, manipulationFunc = None, additionalConstFields = None, header = None):
    if manipulationFunc <> None and type(manipulationFunc) <> dict:
        raise NameError('passed manipulationFunc which should be dict object')
    if additionalConstFields <> None and type(additionalConstFields) <> dict:
        raise NameError('passed additionalConstFields which should be dict object')
    res = list()
    
    allLines = csvContent.splitlines()
    allLines = filter(lambda x: len(x.strip()) > 0 and not(x.startswith('#')), allLines)

    addFieldsCnt = 0
    header = ['command', 'code', 'description']

    if additionalConstFields <> None:
        for exF, exV in additionalConstFields.iteritems():
            header.append(exF)
                
    if additionalConstFields <> None:
        addFieldsCnt = len(additionalConstFields)
                
    fieldCnt = len(header) - addFieldsCnt

    lineNum = 1
    for line in allLines:
        lineNum = lineNum + 1
        allTokens = splitLine(line, delimiter, supportQ)
        allTokens = map(lambda t: t.strip().strip('"') ,allTokens)
        if allTokens[0].startswith('SET') and len(allTokens[0]) > 3:
            allTokens.insert(0, 'SET')
            allTokens[1] = allTokens[1][3:]
        d = dict()
        if len(allTokens) <> fieldCnt:
            #FILE FORMAT
            if len(allTokens) > fieldCnt:
                sys.stderr.write('%s\n'%line)
                raise NameError('Csv Format Exception in line %d excpected for %d tokens'%(lineNum, fieldCnt))
            
        for i in xrange(0, len(allTokens)):
            if len(header[i]) == 0:
                continue
            if manipulationFunc <> None and manipulationFunc.has_key(header[i]):
                handleFunc = manipulationFunc[header[i]]
                d[header[i]] = handleFunc(allTokens[i])
            else:
                d[header[i]] = allTokens[i]
        if additionalConstFields <> None:
            for exF, exV in additionalConstFields.iteritems():
                d[exF] = exV
        for h1 in header:
            if not(d.has_key(h1)) or d[h1] is None:
                d[h1] = ''
        res.append(d)
        
    return res, header

def analyzeMedialFile(f_or_path, delimiter = '\t', supportQ = True, manipulationFunc = None, additionalConstFields = None):
    if type(f_or_path) == str: #first time, f is string path
        if not(os.path.exists(f_or_path)):
            raise NameError('Path not exist')
        f = open(f_or_path, 'r')
    else:
        f = f_or_path
        if f.closed:
            res = [None, None]
            return f, res

    data = f.read()
    f.close()
    [data, header] = analyzeCsv(data, delimiter, supportQ, manipulationFunc, additionalConstFields)
    res = [data,header]
    return f, res

