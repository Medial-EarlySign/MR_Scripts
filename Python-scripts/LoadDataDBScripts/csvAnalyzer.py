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
            
def analyzeCsv(csvContent, delimiter = ',', supportQ = True, manipulationFunc = None, additionalConstFields = None, header = None, select_tokens_fun=None):
    if manipulationFunc <> None and type(manipulationFunc) <> dict:
        raise NameError('passed manipulationFunc which should be dict object')
    if additionalConstFields <> None and type(additionalConstFields) <> dict:
        raise NameError('passed additionalConstFields which should be dict object')
    res = list()
    
    allLines = csvContent.splitlines()
    allLines = filter(lambda x: len(x.strip()) > 0, allLines)

    addFieldsCnt = 0
    if header is None:
        header = allLines[0]
        if select_tokens_fun is None:
            header = map(lambda x: x.strip().strip('"').lower() ,header.split(delimiter))
        else:
            header = map(lambda x: x.strip().strip('"').lower() , select_tokens_fun(header.split(delimiter)))
        allLines = allLines[1:len(allLines)]
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
        if select_tokens_fun is None:
            allTokens = map(lambda t: t.strip().strip('"') ,allTokens)
        else:
            allTokens = select_tokens_fun(map(lambda t: t.strip().strip('"') ,allTokens))
        d = dict()
        if len(allTokens) <> fieldCnt:
            #FILE FORMAT
            if len(allTokens) < fieldCnt:
                sys.stderr.write('%s\n'%line)
                raise NameError('Csv Format Exception in line %d excpected for %d tokens'%(lineNum, fieldCnt))
            allTokens[fieldCnt-1] = delimiter.join(allTokens[fieldCnt-1:])
            allTokens = allTokens[:fieldCnt]
            
        for i in xrange(0, fieldCnt):
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
        res.append(d)
        
    header = filter(lambda x: len(x) > 0 ,header)
    return res, header

def analyzeFile(fpath, delimiter = ',', supportQ = True, manipulationFunc = None, additionalConstFields = None):
    if not(os.path.exists(fpath)):
        raise NameError('Path not exist')
    f = open(fpath, 'r')
    data = f.read()
    f.close()
    return analyzeCsv(data, delimiter, supportQ, manipulationFunc, additionalConstFields)

def analyzeFileTop(fpath, delimiter = ',', topN=1000 ,supportQ = True, manipulationFunc = None, additionalConstFields = None):
    if not(os.path.exists(fpath)):
        raise NameError('Path not exist')
    f = open(fpath, 'r')
    data = ''
    for i in xrange(topN):
        line = f.readline()
        if line is None or len(line) == 0:
            break
        data = data + line
    f.close()
    return analyzeCsv(data, delimiter, supportQ, manipulationFunc, additionalConstFields)

def analyzeFileLazy(f_or_path, delimiter = ',', topN=1000 ,supportQ = True, manipulationFunc = None, additionalConstFields = None, header = None, select_tokens_fun=None):
    if type(f_or_path) == str: #first time, f is string path
        if not(os.path.exists(f_or_path)):
            raise NameError('Path not exist')
        f = open(f_or_path, 'r')
    else:
        f = f_or_path
        if f.closed:
            res = [None, None]
            return f, res
    
    data = ''
    for i in xrange(topN):
        line = f.readline()
        if line is None or len(line) == 0:
            f.close()
            break
        data = data + line
    return f, analyzeCsv(data, delimiter, supportQ, manipulationFunc, additionalConstFields, header, select_tokens_fun)
