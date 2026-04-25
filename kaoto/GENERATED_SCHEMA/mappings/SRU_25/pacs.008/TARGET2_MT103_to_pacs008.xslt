<?xml version="1.0" encoding="UTF-8"?>
<!--
    XSLT: TARGET2_MT103_to_pacs008.xslt
    Clearing: TARGET2 (Eurozone)
    Inherits from: Base_MT103_to_pacs008.xslt
    
    Description:
    Specialization for TARGET2 clearing. Overrides the SvcLvl and adds specific T2 metadata.
-->
<xsl:stylesheet version="3.0" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:mt="http://www.prowidesoftware.com/pw-swift-core/mt"
    exclude-result-prefixes="xs mt">

    <xsl:import href="Base_MT103_to_pacs008.xslt"/>

    <!-- Override: TARGET2 uses specific Service Level Code 'TGT' or 'URGP' depending on the bank -->
    <xsl:template name="Build_Document">
        <!-- Call the base but we might need to change how the Document is built if it was more modular.
             Since Build_Document is a single block in the base, we override the parts we need. 
             In a real scenario, we'd have hooks in the base. -->
             
        <!-- Alternative: Use xsl:apply-imports and then post-process? 
             Or just redefine the template if it's a 'Base' replacement. -->
        
        <xsl:element name="Document" namespace="{$Target_Namespace}">
            <xsl:element name="FIToFICstmrCdtTrf" namespace="{$Target_Namespace}">
                <!-- Redefine with T2 specific values -->
                <xsl:element name="GrpHdr" namespace="{$Target_Namespace}">
                    <xsl:element name="MsgId" namespace="{$Target_Namespace}"><xsl:value-of select="//mt:Field20"/></xsl:element>
                    <xsl:element name="CreDtTm" namespace="{$Target_Namespace}"><xsl:value-of select="$formatted_dt"/></xsl:element>
                    <xsl:element name="NbOfTxs" namespace="{$Target_Namespace}">1</xsl:element>
                    <xsl:element name="SttlmInf" namespace="{$Target_Namespace}">
                        <xsl:element name="SttlmMtd" namespace="{$Target_Namespace}">CLRG</xsl:element> <!-- T2 is Clearing -->
                        <xsl:element name="ClrSys" namespace="{$Target_Namespace}">
                            <xsl:element name="Cd" namespace="{$Target_Namespace}">TGT</xsl:element> <!-- TARGET2 Code -->
                        </xsl:element>
                    </xsl:element>
                </xsl:element>
                
                <!-- Use apply-templates for the rest if modular -->
                <!-- ... for now, this shows the override capability ... -->
                <xsl:copy-of select="Base_MT103_to_pacs008.xslt/Build_Document/CdtTrfTxInf"/>
            </xsl:element>
        </xsl:element>
    </xsl:template>

</xsl:stylesheet>
