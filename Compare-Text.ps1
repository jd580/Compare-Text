<#
.SYNOPSIS
    Outputs a numbered, color coded comparison of two text documents.

.DESCRIPTION
    This function compares two text documents against eachother. The output revolves
    around the reference and the differences are injected and highlighted to give the 
    user a readable comparison to reference. 

.PARAMETER ReferenceConfigPath
    File path to the file to use as a reference

.PARAMETER DifferenceConfigPath
    File path to the file to compare against the reference

.PARAMETER OutputPath
    Path to output the compared file.

.NOTES
    Lines are numbered. 
    Changes in the Difference file are highlighted in Red. 
    If it is a change in texts, the difference is preceded but a green highlighted
    line to show the Reference line that has been changed.
#>

function Compare-TextFile
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ReferenceFilePath,

        [Parameter(Mandatory = $true)]
        [string]
        $DifferenceFilePath,

        [Parameter()]
        [AllowNull()]
        [string]
        $OutputPath
    )

    ##TODO## add output path validation and action. 

    $referenceContent = Get-Content -Path $ReferenceFilePath
    $differenceContent = Get-Content -Path $DifferenceFilePath

    # Create line numbers
    $numberedReference = Add-LineNumber -Text $referenceContent
    $numberedDifference = Add-LineNumber -Text $differenceContent

    # Compare initial objects
    $textDifference = Compare-Object -ReferenceObject $referenceContent -DifferenceObject $differenceContent -IncludeEqual

    # Compare objects with line numbers and sort by line number
    $numberedTextDifference = Compare-Object -ReferenceObject $numberedReference -DifferenceObject $numberedDifference -IncludeEqual -Property Text,LineNum

    foreach ($line in $numberedTextDifference)
    {
        if ($line.SideIndicator -eq '=>')
        {
            $line.LineNum = $line.LineNum - 1
        }
    }

    $numberedTextDifference = $numberedTextDifference | Sort-Object -Property LineNum

    $textResult = Get-NewTextResult -TextDifference $textDifference -CombinedNumberedDifference $numberedTextDifference

    Out-TextResult -TextResult $textResult -OutputPath $OutputPath
}

<#
.SYNOPSIS
    Returns a custom object with each line of text relating to a line number

.PARAMETER Text
    The array of text objects to number
#>
function Add-LineNumber
{
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Text
    )

    $lineNumber = 1
    $return = [System.Collections.ArrayList]::new()
    foreach ($line in $Text)
    {
        $object = New-Object -TypeName psobject -Property @{
            LineNum = $lineNumber
            Text    = $line.Trim()
        }

        $null = $return.Add($object)
        $lineNumber++
    }

    return $return
}

<#
.SYNOPSIS
    Returns a combined, ordered comparison text array

.DESCRIPTION
    Get new Text-Comparison orders and formats the text into a useful text array.
    Each line starts with a number. If there is no difference noted, it has no identifier. 
    If it does, it identifies which file it representing. E.g ::Reference:: followed by the actual line text

.PARAMETER TextDifference
    The difference object without numbers

.PARAMETER CombinedNumberedDifference
    The numbered difference of both the Reference and Difference files.

.NOTES
General notes
#>

function Get-NewTextResult
{
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $TextDifference,

        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $CombinedNumberedDifference
    )

    # Array list for equal, ReferenceDifference and DifferenceDifference
    $equalArray = [System.Collections.ArrayList]::new()
    $referenceArray = [System.Collections.ArrayList]::new()
    $differenceArray = [System.Collections.ArrayList]::new()

    # separate $TextDifference into appropriate arrays
    foreach ($diff in $textDifference)
    {
        switch ($diff.SideIndicator)
        {
            '=='
            {
                $null = $equalArray.Add($diff)
                break
            }
            '<='
            {
                $null = $referenceArray.Add($diff)
                break
            }
            '=>'
            {
                $null = $differenceArray.Add($diff)
            }
        }
    }

    $finalCollection = [System.Collections.ArrayList]::new()
    $diffCollection = [System.Collections.ArrayList]::new()
    $lineCount = 1
    foreach ($line in $CombinedNumberedDifference)
    {
        switch ($line.Text) 
        {
            {$PSItem -eq $equalArray[0].InputObject} 
            {
                if ($diffCollection.Count -gt 0)
                {
                    [int] $byte = 97 # Lowercase A
                    foreach ($diffLine in $diffCollection)
                    {
                        $diffLineCount = "$($lineCount - 1).$([CHAR][BYTE]$byte)"
                        $diffString = "[{0}]::Difference::`t{1}" -f $diffLineCount, $diffLine
                        $byte ++

                        $null = $finalCollection.Add($diffString)
                    }

                    $diffCollection.Clear()
                }
                
                $strLine = $line.Text
                $strLine = $strLine.replace("`t"," ")
                $equalString = "[{0}]`t{1}" -f $lineCount, $strLine 

                $null = $finalCollection.Add($equalString)
                $null = $equalArray.Remove($equalArray[0])
                break
            }
            {$PSItem -eq $referenceArray[0].InputObject}
            {
                if ($diffCollection.Count -gt 0)
                {
                    [int] $byte = 97 # Lowercase A
                    foreach ($diffLine in $diffCollection)
                    {
                        $diffLineCount = "$($lineCount - 1).$([CHAR][BYTE]$byte)"
                        $diffString = "[{0}]::Difference::`t{1}" -f $diffLineCount, $diffLine
                        $byte ++

                        $null = $finalCollection.Add($diffString)
                    }

                    $diffCollection.Clear()
                }

                $referenceString = "[{0}]::Reference::`t{1}" -f $lineCount, $line.Text
                $null = $finalCollection.Add($referenceString)
                $null = $referenceArray.Remove($referenceArray[0])
                break
            }
            {$PSItem -eq $differenceArray[0].InputObject}
            {
                $null = $diffCollection.Add($line.Text)
                $null = $differenceArray.Remove($differenceArray[0])

                $lineCount = $lineCount - 1
            }
        }

        $lineCount++
    }

    # If the process ends with any lines in $differenceArray, those lines are lost. so we need 
    # to clarify that everything is added to the $finalCollection here.

    if ($diffCollection.Count -gt 0)
    {
        [int] $byte = 97 # Lowercase A
        foreach ($diffLine in $diffCollection)
        {
            $diffLineCount = "$($lineCount - 1).$([CHAR][BYTE]$byte)"
            $diffString = "[{0}]::Difference::`t{1}" -f $diffLineCount, $diffLine
            $byte ++

            $null = $finalCollection.Add($diffString)
        }
    }

    return $finalCollection
}

<#
.SYNOPSIS
Writes the output to the Host and file if specified.

.PARAMETER TextResult
    Fully formatted text object to output

.PARAMETER OutputPath
    File path to output results.
#>
function Out-TextResult
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $TextResult,

        [Parameter()]
        [AllowNull()]
        [string]
        $OutputPath
    )

    if ($OutputPath)
    {
        $TextResult | Out-File -FilePath $OutputPath 
    }

    foreach ($line in $TextResult)
    {
        switch ($line)
        {
            {$PSItem -match '.*::Reference::.*'}
            {
                Write-Host -Object $line -BackgroundColor Green -ForegroundColor Black
                break
            }
            {$PSItem -match '.*::Difference::.*'}
            {
                Write-Host -Object $line -BackgroundColor Red -ForegroundColor Black
                break
            }
            default
            {
                Write-Output -InputObject $line
            }
        }
    }
}

#$time = Measure-Command {Compare-TextFile -ReferenceFilePath 'C:\Temp\test1.txt' -DifferenceFilePath 'C:\Temp\test2.txt' -OutputPath C:\temp\outputtest.txt}