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
        $OutputPath,

        [Parameter()]
        [switch]
        $SkipOutput
    )

    ##TODO## add output path validation and action. 

    $referenceContent = Get-Content -Path $ReferenceFilePath
    $differenceContent = Get-Content -Path $DifferenceFilePath

    # Create line numbers
    #$lineNumberTime = Measure-Command {
        $numberedReference = Add-LineNumber -Text $referenceContent
        $numberedDifference = Add-LineNumber -Text $differenceContent
    #}
    # Compare initial objects
    #$normalCompareTime = Measure-Command {
        $textComparison = Compare-Object -ReferenceObject $referenceContent -DifferenceObject $differenceContent -IncludeEqual
    #}

    # Compare objects with line numbers and sort by line number
    #$numberedCompareTime = Measure-Command {
    #    $numberedTextComparison = Compare-Object -ReferenceObject $numberedReference -DifferenceObject $numberedDifference -IncludeEqual -Property Text,LineNum
    #}
    #$numberedCompareTime = Measure-Command {
        $numberedTextComparison = Format-ComparedObject -NumberedReference $numberedReference -NumberedDifference $numberedDifference -TextComparison $textComparison
    #}

    #$numberSortingTime = Measure-Command {
        $numberedTextComparison = $numberedTextComparison | Sort-Object -Property LineNum
    #}
    #$FullSortingtime = Measure-Command {
        $textResult = Get-NewTextResult -TextComparison $textComparison -CombinedNumberedDifference $numberedTextComparison
    #}
    #$outingTime = Measure-Command {
        if ($SkipOutput)
        {
            Out-TextResult -TextResult $textResult -OutputPath $OutputPath -SkipOutput
        }
        else
        {
            Out-TextResult -TextResult $textResult -OutputPath $OutputPath
        }
    #}

    #$return = @{
    #    LineNumbering = $lineNumberTime
    #    NormalCompare = $normalCompareTime
    #    NumberCompare = $numberedCompareTime
    #    Renumbering   = $renumberTime
    #    NumberSorting = $numberSortingTime
    #    FullSorting   = $FullSortingtime
    #    OutingTime    = $outingTime
    #}
    #
    #return $return
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
            LineNum       = $lineNumber
            Text          = $line.Trim()
            SideIndicator = $null
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

.PARAMETER TextComparison
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
        $TextComparison,

        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $CombinedNumberedDifference
    )

    # Array list for equal, ReferenceDifference and DifferenceDifference
    $equalArray = [System.Collections.ArrayList]::new()
    $referenceArray = [System.Collections.ArrayList]::new()
    $differenceArray = [System.Collections.ArrayList]::new()

    # separate $TextComparison into appropriate arrays
    foreach ($diff in $TextComparison)
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
        $OutputPath,

        [Parameter()]
        [switch]
        $SkipOutput
    )

    if ($OutputPath)
    {
        $TextResult | Out-File -FilePath $OutputPath 
    }

    if (-not $SkipOutput)
    {
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
}

function Format-ComparedObject
{
    param
    (
        [Parameter(Mandatory = $true)]
        $NumberedReference,

        [Parameter(Mandatory = $true)]
        $NumberedDifference,

        [Parameter(Mandatory = $true)]
        $TextComparison
    )

    [System.Collections.ArrayList] $referenceClone = $TextComparison.Clone()
    $refToRemove = $referenceClone | Where-Object -FilterScript {$_.SideIndicator -eq '=>'}
    foreach ($ref in $refToRemove)
    {
        $referenceClone.Remove($ref)
    }

    [System.Collections.ArrayList] $differenceClone = $TextComparison.Clone()
    $diffToRemove = $differenceClone | Where-Object -FilterScript {$_.SideIndicator -eq '<=' -or $_.SideIndicator -eq '=='}
    foreach ($diff in $diffToRemove)
    {
        $differenceClone.Remove($diff)
    }
    [System.Collections.ArrayList] $numberedReferenceClone = $NumberedReference.Clone()
    [System.Collections.ArrayList] $numberedDifferenceClone = $NumberedDifference.Clone()

    foreach ($index in 0..($NumberedReference.Count - 1))
    {
        [System.Collections.ArrayList] $referenceClone = $referenceClone
        foreach ($compareLine in $referenceClone)
        {
            if ($NumberedReference[$index].Text -eq $compareLine.InputObject)
            {
                if ($compareLine.SideIndicator -eq '==')
                {
                    $numberedReferenceClone[$index].SideIndicator = '=='
                    $referenceClone.Remove($compareLine)
                    break
                }
                else 
                {
                    $numberedReferenceClone[$index].SideIndicator = '<='
                    $referenceClone.Remove($compareLine)
                    break
                }
            }
        }
    }

    foreach ($index in 0..($NumberedDifference.Count - 1))
    {
        [System.Collections.ArrayList] $differenceClone = $differenceClone
        foreach ($compareLine in $differenceClone)
        {
            if ($NumberedDifference[$index].Text -eq $compareLine.InputObject)
            {
                $numberedDifferenceClone[$index].SideIndicator = '=>'
                $differenceClone.Remove($compareLine)
                break
            }
        }
    }

    $diffCleanup = $numberedDifferenceClone | Where-Object -FilterScript {$_.SideIndicator -ne '=>'}
    foreach ($obj in $diffCleanup)
    {
        $numberedDifferenceClone.Remove($obj)
    }

    [System.Collections.ArrayList] $numberedDifferenceClone = Group-Difference -DifferenceArray $numberedDifferenceClone

    $combinedList = [System.Collections.ArrayList]::new()
    $combinedList.AddRange($numberedReferenceClone)
    $combinedList.AddRange($numberedDifferenceClone)

    return $combinedList
}

function Group-Difference
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
        $DifferenceArray
    )

    [System.Collections.ArrayList] $DifferenceArrayClone = $DifferenceArray.Clone()
    foreach ($index in 0..($DifferenceArray.Count - 1))
    {
        $tracking = [System.Collections.ArrayList]::new()
        if ($index -notin $tracking)
        {
            $null = $tracking.Add($index)
            $baseLineNumber = $DifferenceArray[$index].LineNum
            $addCount = 1

            while ($true)
            {
                if (($baseLineNumber + $addCount) -eq ($DifferenceArray[($index + $addCount)].LineNum))
                {
                    $null = $tracking.Add($index + $addCount)
                    $finalLineNumber = $baseLineNumber + $addCount
                    $addCount++
                }
                else
                {
                    if ($tracking.Count -gt 1)
                    {
                        foreach ($item in $tracking)
                        {
                            $DifferenceArrayClone[$item].LineNum = $finalLineNumber
                        }
                    }

                    break
                }
            }
        }
    }

    return $DifferenceArrayClone
}

<#$Totaltime = Measure-Command { $timeResults = #>Compare-TextFile -ReferenceFilePath 'C:\Temp\test3.txt' -DifferenceFilePath 'C:\Temp\test4.txt' -OutputPath C:\temp\outputtest.txt #}