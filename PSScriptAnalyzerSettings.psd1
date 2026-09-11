@{
    # Include default built-in PSScriptAnalyzer rules
    IncludeRules = @('PS*')

    # Exclude rules that produce false positives for terminal CLI scripts
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSUseBOMForUnicodeEncodedFile',
        'PSAvoidUsingEmptyCatchBlock',
        'PSUseApprovedVerbs'
    )

    # Formatting rules
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable          = $true
            IndentationSize = 4
        }
        PSUseConsistentWhitespace  = @{
            Enable          = $true
            CheckOpenBrace  = $true
            CheckOpenParen  = $true
            CheckOperator   = $true
            CheckSeparator  = $true
        }
    }
}
