/** @file CoilArray.cpp
 *  @brief Implementation of JEMRIS CoilArray
 */

/*
 *  JEMRIS Copyright (C) 
 *                        2006-2013  Tony Stoecker
 *                        2007-2013  Kaveh Vahedipour
 *                        2009-2013  Daniel Pflugfelder
 *                                  
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "BinaryContext.h"
#include "CoilArray.h"
#include "Coil.h"
#include "StrX.h"
#include <sstream>

/***********************************************************/
CoilArray::CoilArray () {

    m_dom_doc = 0;
    m_mode    = RX;
    m_signal_prefix = "signal";
    m_cpf     = new CoilPrototypeFactory();
    m_xio     = new XMLIO();

}

/***********************************************************/
CoilArray::~CoilArray() {

	delete m_xio;
	delete m_cpf;
	XMLPlatformUtils::Terminate();

}

/***********************************************************/
unsigned int CoilArray::Populate () {

	DOMNode* topnode;

	if (!(topnode = m_dom_doc->getFirstChild()))
		return EMPTY_DOCUMENT;

	if ((string)StrX(topnode->getNodeName()).localForm() != "CoilArray")
		return EMPTY_DOCUMENT;

	RunTree(topnode, this, &CoilArray::CreateCoil);

	//Prepare(PREP_INIT);
	Prepare(PREP_VERBOSE);

	return OK;

}

/***********************************************************/
bool CoilArray::Prepare (PrepareMode mode) {

	for (unsigned int i=0; i<m_coils.size(); i++)
		m_coils.at(i)->Prepare(mode);

	return true;

}

/***********************************************************/
unsigned int CoilArray::CreateCoil (void* ptr,DOMNode* node) {

	CoilArray* CA = (CoilArray*) ptr;
	Coil* coil    = CA->m_cpf->Clone(node);
	if (!coil)
		return 1;
	CA->m_coils.push_back(coil);
	coil->Initialize(node);
	return OK;

}

/**************************************************/
DOMNode* CoilArray::RunTree (DOMNode* node, void* ptr, unsigned int (*fun) (void*, DOMNode*) ) {

	DOMNode* child;
	DOMNode* rnode = NULL;

	if (node) {


		if (node->getNodeType() == DOMNode::ELEMENT_NODE) {

			if ((string)StrX(node->getNodeName()).localForm() != "CoilArray")
				if (fun(ptr,node)>0)
					return node;

			for (child = node->getFirstChild(); child != 0; child=child->getNextSibling()) {
			    rnode = RunTree(child,ptr,fun);
			    if (rnode!=NULL) break;
			}
		}
	}

	return rnode;

}


/**************************************************/
void CoilArray::Initialize (string uri) {

   	m_dom_doc = m_xio->Parse(uri.c_str());

}

/**************************************************/
void CoilArray::InitializeSignals (long lADCs) {

	for (unsigned int i=0; i<GetSize(); i++)
		m_coils[i]->InitSignal(lADCs);

}

/**************************************************/
void CoilArray::Receive (long lADC){

	for (unsigned int i=0; i<GetSize(); i++)
		m_coils[i]->Receive(lADC);

}

/**********************************************************/
IO::Status CoilArray::DumpSignals (string prefix, bool normalize) {

	/*	if (prefix != "")
		m_signal_prefix = "channel";
	
	for (unsigned int i=0; i < GetSize(); i++) {

	    m_coils[i]->GetSignal()->DumpTo(sstr.str(),normalize);

		}*/


	BinaryContext bc ("signals.h5", IO::OUT);
	NDData<double> di;
	std::string URL, URN;

	for (int c = 0; c < GetSize(); c++) {
		
		Repository* repository = m_coils[c]->GetSignal()->Repo();
		RNG*        rng        = m_coils[c]->GetSignal()->Noise();

		for (long i = 0; i < repository->Samples(); i++) {
			
			if (normalize) {
				
				for (int j = 0; j < repository->NProps(); j++) 
					(*repository)[i*repository->NProps() + j] /= World::instance()->TotalSpinNumber;
				
				//dwelltime-weighted random noise
				if (World::instance()->RandNoise > 0.0) {
					
					double dt =  1.0;
					
					if      (i                    > 0) dt = repository->TP(i  ) - repository->TP(i-1);
					else if (repository->Samples() > 1) dt = repository->TP(i+1) - repository->TP(i  );
					
					//definition: Gaussian has std-dev World::instance()->RandNoise at a dwell-time of 0.01 ms
					for (int j = 0; j < repository->Compartments(); j++) {
						(*repository)[i*repository->NProps() + j*3 + 0] += World::instance()->RandNoise*rng->normal()*0.1/sqrt(dt);
						(*repository)[i*repository->NProps() + j*3 + 1] += World::instance()->RandNoise*rng->normal()*0.1/sqrt(dt);
					}
					
				}

			}
			
		}

		stringstream sstr;
		sstr << setw(2) << setfill('0') << c;

		di = NDData<double> (repository->Samples(), repository->NProps());
		memcpy (&di[0], repository->Data(), di.Size() * sizeof(double));
		URN = sstr.str();
		bc.WriteData (di, URN, "/signal/channels/");
		
		if (URN == "00") {
			di = NDData<double> (repository->Samples());
			memcpy (&di[0], repository->Times(), di.Size() * sizeof(double));
			bc.WriteData (di, "times", "/signal");
		}


	}

	//REVISE
	return IO::OK;
	
}

/**********************************************************/
IO::Status CoilArray::DumpSensMaps (bool verbose) {
	
	BinaryContext bc (std::string("sensmaps.h5"), IO::OUT);
	NDData<double>      di (
			m_coils.size(),
		   (m_coils[0]->GetNDim() == 3) ? m_coils[0]->GetPoints() : 1,
		    m_coils[0]->GetPoints(), m_coils[0]->GetPoints());
	IO::Status    ios = IO::OK;
	
	
	if (bc.Status() != IO::OK)
		return bc.Status();

	long size = di.Size();

	for (unsigned i = 0, n = 0; i < m_coils.size(); ++i) {
		m_coils[i]->GridMap();
		memcpy (&di[0], m_coils[i]->MagnitudeMap(), sizeof(double)*size);
		n += size; 
	}
	bc.WriteData (di, "magnitude", "/maps");

	for (unsigned i = 0, n = 0; i < m_coils.size(); ++i) {
		memcpy (&di[0], m_coils[i]->PhaseMap(), sizeof(double)*size);
		n += size; 
	}
	bc.WriteData (di, "phase", "/maps");
	
	return ios;
	
}

/**********************************************************/
Coil* CoilArray::GetCoil(unsigned channel) {

	if (channel<m_coils.size())
		return m_coils[channel];
	else
		return NULL;
}

/**********************************************************/
int CoilArray::ReadRestartSignal(){

	/*	// return: 0, if files successfully read; -2 if no files present; -1 if wrong restart files.
	bool fail = false;
	for (unsigned int i=0; i<GetSize();i++) {
		Repository rep = m_coils[i]->GetSignal()->m_repository;
		ifstream tmp;
	    stringstream sstr;
		sstr << ".tmp_sig" << setw(2) << setfill('0') << i+1 << ".bin";
		tmp.open(sstr.str().c_str(), ifstream::binary);
		if (!tmp.is_open()) {
			if (i==0) return (-2); else fail=true;
		}
		tmp.seekg (0, ios::end);
		// REVISE works only for single compartment
		int length = tmp.tellg()/sizeof(double)/4;
		if (length != rep.size) fail=true;
		if (fail) {
			tmp.close();
			for (unsigned int j=0;j<GetSize();j++) {
				m_coils[j]->InitSignal(rep.size);
			}
			return (-1);
		}
		tmp.seekg (0, ios::beg);
		for (int k=0; k<length;k++) {
			tmp.read ((char*) &(rep.tp[k]),sizeof(double));
			tmp.read ((char*) &(rep.mx[k]),sizeof(double));
			tmp.read ((char*) &(rep.my[k]),sizeof(double));
			tmp.read ((char*) &(rep.mz[k]),sizeof(double));
		}
		tmp.close();
		}*/
	return (0);
}
