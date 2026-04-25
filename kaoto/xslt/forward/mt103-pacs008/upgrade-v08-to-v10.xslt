<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:v08="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.08"
    xmlns="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10"
    xmlns:head="urn:iso:std:iso:20022:tech:xsd:head.001.001.02"
    exclude-result-prefixes="xs v08">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <!-- Identity Template -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Patch: Upgrade pacs.008 Namespace to v10 -->
  <xsl:template match="v08:*">
    <xsl:element name="{local-name()}" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
      <xsl:apply-templates select="@*|node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Feature: Enforce Structured Address for v10 -->
  <xsl:template match="v08:PstlAdr">
    <xsl:element name="PstlAdr" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
      <xsl:apply-templates select="v08:Ctry"/>
      <!-- In v10, if we have a town-like line, we move it to TownName -->
      <xsl:variable name="town_candidate" select="v08:AdrLine[last()-1]"/>
      <xsl:if test="$town_candidate and string-length(normalize-space($town_candidate)) > 0">
        <xsl:element name="TownName" namespace="urn:iso:std:iso:20022:tech:xsd:pacs.008.001.10">
          <xsl:value-of select="normalize-space($town_candidate)"/>
        </xsl:element>
      </xsl:if>
      <!-- Preserve other lines -->
      <xsl:apply-templates select="v08:AdrLine"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="head:MsgDefIdr">
    <xsl:element name="MsgDefIdr" namespace="urn:iso:std:iso:20022:tech:xsd:head.001.001.02">
      <xsl:text>pacs.008.001.10</xsl:text>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
