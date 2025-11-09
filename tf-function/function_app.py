import azure.functions as func
import logging
import json
import re
import os
from fpdf import FPDF
from azure.storage.blob import BlobServiceClient

# Blob storage settings from environment variables
BLOB_CONNECTION_STRING = os.environ["BLOB_CONNECTION_STRING"] # Remmber to set this in function app settings
BLOB_CONTAINER_NAME = os.environ["BLOB_CONTAINER_NAME"] # Remembver to create this container in blob storage account

# Initialize BlobServiceClient
blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
container_client = blob_service_client.get_container_client(BLOB_CONTAINER_NAME)

# Boilerplate Case Terms
BOILERPLATE_TERMS = """
1. Representation Scope
The Firm agrees to provide legal services to the Client in connection with the specified case. The scope of representation is limited to the matters explicitly discussed and agreed upon in this engagement.

2. Client Responsibilities
The Client agrees to provide full and truthful information, respond to inquiries promptly, and cooperate with the Firm in all aspects of the representation.

3. Fees and Billing
The Firm will bill the Client in accordance with the agreed fee arrangement. Invoices are due upon receipt unless otherwise agreed. The Client is responsible for all reasonable costs and expenses incurred during the representation.

4. Confidentiality
All information exchanged between the Client and the Firm shall remain strictly confidential in accordance with applicable laws and professional ethical rules.

5. Termination
Either party may terminate the engagement at any time upon written notice. Termination does not relieve the Client of responsibility for fees or costs incurred prior to termination.

6. Limitation of Liability
The Firm makes no guarantees regarding outcomes. The Client acknowledges that legal results cannot be assured and agrees that the Firm's liability is limited to the extent permitted by law.

7. Governing Law
This engagement and all matters arising from it shall be governed by and construed in accordance with the laws of the jurisdiction in which the Firm is licensed to practice.

8. Acceptance
By continuing to work with the Firm, the Client acknowledges that they have read, understood, and agreed to these terms.
"""

app = func.FunctionApp()

#decorators for trigger
@app.service_bus_topic_trigger(
    arg_name="azservicebus",
    subscription_name="client-subscription",
    topic_name="clienttopic",
    connection="ServiceBusConnection"
)
def servicebus_topic_trigger(azservicebus: func.ServiceBusMessage):
    """Generates a PDF for new client with case info and boilerplate terms, then uploads to Blob Storage."""

    message_body = azservicebus.get_body().decode('utf-8')
    logging.info('Processing Service Bus message: %s', message_body)

    # Parse JSON to get client_name and case
    try:
        data = json.loads(message_body)
        client_name = data.get("client_name", "unknown-client")
        case_name = data.get("case", "caseunknown")
    except (ValueError, TypeError):
        client_name = "unknown-client"
        case_name = "caseunknown"

    # Sanitize client name for safe blob filename
    blob_name = re.sub(r"[^a-zA-Z0-9_-]", "_", client_name) + ".pdf"

    # Generate PDF
    pdf = FPDF()
    pdf.add_page()

    # Header: Client Name & Case
    pdf.set_font("Arial", "B", 16)
    pdf.cell(0, 10, f"Client Name: {client_name}", ln=True)
    pdf.cell(0, 10, f"Case: {case_name}", ln=True)
    pdf.ln(10)

    # Body: Boilerplate terms
    pdf.set_font("Arial", "", 12)
    pdf.multi_cell(0, 8, BOILERPLATE_TERMS)

    # Get PDF as bytes
    pdf_output = pdf.output(dest='S').encode('latin1')

    # Upload PDF to blob storage (overwrites if exists)
    try:
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(pdf_output, overwrite=True)
        logging.info(f"PDF written to blob: {BLOB_CONTAINER_NAME}/{blob_name}")
    except Exception as e:
        logging.error(f"Failed to write PDF blob: {e}")
