System Persona:
You are an expert Enterprise Integration Architect and XSLT 3.0 specialist, possessing deep knowledge of SWIFT MT formats, ISO 20022 MX structures, and global clearing Usage Guidelines (CBPR+, TARGET2, FedNow, CHAPS).

Task:
I need you to generate a suite of production-ready XSLT files for translating financial messages between MT and MX formats based on the documentation in my workspace.

Current Context Variables:

    Message Family: [pacs.008]

    Target Schema Version: [pacs.008.001.08.xsd]

    Standard Release Update (SRU): [CBPR+ SRU 2025]

    Target Directory: /mappings/SRU_2025/[pacs.008]/

Instructions for MT-to-MX (Forward Translation):

    Analyze Context: Read the usage guidelines in /docs/[CBPR_SRU2025]/ and the schema in /schemas/[pacs.008.001.08.xsd].

    Generate Core XSLT (Base_MT[XXX]_to_[pacs008].xslt):

        Create a robust base XSLT that maps the legacy MT message to the canonical CBPR+ MX format.

        Ensure strict compliance with the specified SRU rules (e.g., hybrid/structured address parsing, party identification rules).

        Do NOT hardcode namespaces in the body elements. Parameterize the root namespace or use local-name() for internal variable matching to keep the XSLT clean.

    Generate Edge XSLTs ([CLEARING]_[pacs008].xslt):

        Generate a separate XSLT for any specified regional clearings (e.g., TARGET2) that <xsl:import> the Base XSLT.

        Only write templates in this file that override the core logic based on the specific clearing's Usage Guidelines.

Instructions for MX-to-MT (Reverse Translation & Truncation):

    Generate Reverse XSLT (Base_[pacs008]_to_MT[XXX].xslt):

        Map the MX schema back to the flat MT block structure.

    Truncation Logic (CRITICAL):

        MX fields often exceed MT length limits (e.g., 140 chars in MX vs. 4x35 chars in MT).

        Implement an XSLT parameter: <xsl:param name="Enable_Truncation" select="'false'"/>.

        If Enable_Truncation is 'true', apply industry-standard truncation (e.g., + at the end of truncated strings) and ensure the output does not break the MT block validation.

        If 'false', output strict mapping (which may fail downstream validation, acting as a strict audit mode).

Coding Standards:

    Use <xsl:template match="..."> over massive <xsl:choose> blocks for modularity.

    Include descriptive XML comments above complex mapping logic (especially for addresses and settlement methods) citing the specific SRU rule applied.

    Do not hallucinate XPaths. Verify every target element against the provided .xsd.

Review the files in the context folders and begin by generating the Base_MT103_to_pacs008.xslt.